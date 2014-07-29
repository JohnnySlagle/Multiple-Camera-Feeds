//
//  JSReplicatorLayerViewController.m
//  MultipleCameraFeeds
//
//  Created by Johnny Slagle on 7/27/14.
//  Copyright (c) 2014 Johnny Slagle. All rights reserved.
//

#import "JSReplicatorLayerViewController.h"

@import AVFoundation;

@interface JSReplicatorLayerViewController ()

@end

@implementation JSReplicatorLayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // UI
    self.edgesForExtendedLayout = UIRectEdgeNone;

    // Setup
    [self setupReplicatorLayers];
}


- (void)setupReplicatorLayers
{
    // Session
    AVCaptureSession *session = [AVCaptureSession new];
    
    // Capture device
    AVCaptureDevice *inputDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    
    // Device input
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:inputDevice error:&error];
    if ( [session canAddInput:deviceInput] ) {
        [session addInput:deviceInput];
    }
    
    // Preview
    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [previewLayer setFrame:CGRectMake(0.0, 0.0, self.view.bounds.size.width, self.view.bounds.size.height)];
    
    NSUInteger replicatorInstances = 4;
    CGFloat replicatorViewHeight = (self.view.bounds.size.height - 64)/replicatorInstances; // Note: 64.0 is to account for the status bar and navigation bar

    
    //Create the replicator layer
    CAReplicatorLayer *replicatorLayer = [CAReplicatorLayer layer];
    replicatorLayer.frame = CGRectMake(0, 0.0, self.view.bounds.size.width, replicatorViewHeight);
    replicatorLayer.instanceCount = replicatorInstances;
    replicatorLayer.instanceTransform = CATransform3DMakeTranslation(0.0, replicatorViewHeight, 0.0);
    
    [replicatorLayer addSublayer:previewLayer];
    [self.view.layer addSublayer:replicatorLayer];
    
    [session startRunning];
}

@end
