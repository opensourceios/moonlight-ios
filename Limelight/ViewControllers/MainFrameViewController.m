//
//  MainFrameViewController.m
//  Limelight-iOS
//
//  Created by Diego Waxemberg on 1/17/14.
//  Copyright (c) 2014 Diego Waxemberg. All rights reserved.
//

#import "MainFrameViewController.h"
#import "Computer.h"
#import "CryptoManager.h"
#import "HttpManager.h"
#import "Connection.h"
#import "VideoDecoderRenderer.h"
#import "StreamManager.h"
#import "Utils.h"

@implementation MainFrameViewController {
    NSOperationQueue* _opQueue;
    MDNSManager* _mDNSManager;
    Computer* _selectedHost;
    UIAlertView* _pairAlert;
}
static StreamConfiguration* streamConfig;

+ (StreamConfiguration*) getStreamConfiguration {
    return streamConfig;
}

- (void)PairButton:(UIButton *)sender
{
    NSLog(@"Pair Button Pressed!");
    if ([self.hostTextField.text length] > 0) {
        _selectedHost = [[Computer alloc] initWithIp:self.hostTextField.text];
        NSLog(@"Using custom host: %@", self.hostTextField.text);
    }
    [CryptoManager generateKeyPairUsingSSl];
    NSString* uniqueId = [CryptoManager getUniqueID];
    NSData* cert = [CryptoManager readCertFromFile];
    
    HttpManager* hMan = [[HttpManager alloc] initWithHost:_selectedHost.hostName uniqueId:uniqueId deviceName:@"roth" cert:cert];
    PairManager* pMan = [[PairManager alloc] initWithManager:hMan andCert:cert callback:self];

    [_opQueue addOperation:pMan];
}

- (void)showPIN:(NSString *)PIN {
    dispatch_sync(dispatch_get_main_queue(), ^{
        _pairAlert = [[UIAlertView alloc] initWithTitle:@"Pairing" message:[NSString stringWithFormat:@"Enter the following PIN on the host machine: %@", PIN]delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [_pairAlert show];
    });
}

- (void)pairFailed:(NSString *)message {
    dispatch_sync(dispatch_get_main_queue(), ^{
        [_pairAlert dismissWithClickedButtonIndex:0 animated:NO];
        _pairAlert = [[UIAlertView alloc] initWithTitle:@"Pairing Failed" message:message delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [_pairAlert show];
    });
}

- (void)pairSuccessful {
    dispatch_sync(dispatch_get_main_queue(), ^{
        [_pairAlert dismissWithClickedButtonIndex:0 animated:NO];
        _pairAlert = [[UIAlertView alloc] initWithTitle:@"Pairing Succesful" message:@"Successfully paired to host" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [_pairAlert show];
    });
}

- (void)StreamButton:(UIButton *)sender
{
    NSLog(@"Stream Button Pressed!");
    if ([self.hostTextField.text length] > 0) {
        _selectedHost = [[Computer alloc] initWithIp:self.hostTextField.text];
        NSLog(@"Using custom host: %@", self.hostTextField.text);
    }
    streamConfig = [[StreamConfiguration alloc] init];
    streamConfig.host = _selectedHost.hostName;
    streamConfig.hostAddr = [Utils resolveHost:_selectedHost.hostName];
    
    unsigned long selectedConf = [self.StreamConfigs selectedRowInComponent:0];
    NSLog(@"selectedConf: %ld", selectedConf);
    switch (selectedConf) {
        case 0:
            streamConfig.width = 1280;
            streamConfig.height = 720;
            streamConfig.frameRate = 30;
            break;
        case 1:
            streamConfig.width = 1280;
            streamConfig.height = 720;
            streamConfig.frameRate = 60;
            break;
        case 2:
            streamConfig.width = 1920;
            streamConfig.height = 1080;
            streamConfig.frameRate = 30;
            break;
        case 3:
            streamConfig.width = 1920;
            streamConfig.height = 1080;
            streamConfig.frameRate = 60;
            break;
        default:
            streamConfig.width = 1280;
            streamConfig.height = 720;
            streamConfig.frameRate = 60;
            break;
    }
    NSLog(@"StreamConfig: %@, %d, %dx%dx%d", streamConfig.host, streamConfig.hostAddr, streamConfig.width, streamConfig.height, streamConfig.frameRate);
    [self performSegueWithIdentifier:@"createStreamFrame" sender:self];
}

- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component
{
    if (pickerView == self.StreamConfigs) {
        return [self.streamConfigVals objectAtIndex:row];
    } else if (pickerView == self.HostPicker) {
        return ((Computer*)([self.hostPickerVals objectAtIndex:row])).displayName;
    } else {
        return nil;
    }
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    if (pickerView == self.HostPicker) {
        _selectedHost = (Computer*)([self.hostPickerVals objectAtIndex:[self.HostPicker selectedRowInComponent:0]]);
    }
    
    //TODO: figure out how to save this info!!
}

// returns the number of 'columns' to display.
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component
{
    if (pickerView == self.StreamConfigs) {
        return self.streamConfigVals.count;
    } else if (pickerView == self.HostPicker) {
        return self.hostPickerVals.count;
    } else {
        return 0;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.streamConfigVals = [[NSArray alloc] initWithObjects:@"1280x720 (30Hz)", @"1280x720 (60Hz)", @"1920x1080 (30Hz)", @"1920x1080 (60Hz)",nil];
    self.hostPickerVals = [[NSArray alloc] init];
    [self.StreamConfigs selectRow:1 inComponent:0 animated:NO];
    
    _mDNSManager = [[MDNSManager alloc] initWithCallback:self];
    [_mDNSManager searchForHosts];
    _opQueue = [[NSOperationQueue alloc] init];
}

- (void)updateHosts:(NSArray *)hosts {
    self.hostPickerVals = hosts;
    [self.HostPicker reloadAllComponents];
    _selectedHost = (Computer*)([self.hostPickerVals objectAtIndex:[self.HostPicker selectedRowInComponent:0]]);
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    NSString *deviceType = [UIDevice currentDevice].model;
    if ([deviceType containsString:@"iPhone"] || [deviceType containsString:@"iPod"]) {
        return UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskPortraitUpsideDown;
    } else {
        return UIInterfaceOrientationMaskLandscapeLeft | UIInterfaceOrientationMaskLandscapeRight;
    }
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    NSString *deviceType = [UIDevice currentDevice].model;
    if ([deviceType containsString:@"iPhone"] || [deviceType containsString:@"iPod"]) {
        return UIInterfaceOrientationPortrait;
    } else {
        return UIInterfaceOrientationLandscapeRight;
    }
}
@end