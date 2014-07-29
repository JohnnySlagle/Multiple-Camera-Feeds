//
//  JSOpenGLFeedsViewController.m
//  MultipleCameraFeeds
//
//  Created by Johnny Slagle on 7/27/14.
//  Copyright (c) 2014 Johnny Slagle. All rights reserved.
//

#import "JSOpenGLFeedsViewController.h"

@import AVFoundation;
@import GLKit;


#pragma mark - Custom GLKView

// Note: I made this subclass to streamline the sample code. Fully accept it might not be the best way to do this.

@interface GLKViewWithBounds : GLKView

@property (nonatomic, assign) CGRect viewBounds;

@end


@implementation GLKViewWithBounds

@end


#pragma mark - View Controller

@interface JSOpenGLFeedsViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>

@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, strong) EAGLContext *eaglContext;

@property (nonatomic, strong) AVCaptureSession *captureSession;

@property (nonatomic, strong) dispatch_queue_t captureSessionQueue;

@property (nonatomic, assign) CMVideoDimensions currentVideoDimensions;

@property (nonatomic, strong) NSMutableArray *feedViews;

@end


@implementation JSOpenGLFeedsViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // UI
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.view.backgroundColor = [UIColor blackColor];
    self.title = @"OpenGL";

    // Data Source
    self.feedViews = [NSMutableArray array];
    
    // see if we have any video device
    if ([[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 0) {
        // create the dispatch queue for handling capture session delegate method calls
        _captureSessionQueue = dispatch_queue_create("capture_session_queue", NULL);
        
        // Contexts
        [self setupContexts];

        // Sessions
        [self setupSession];
        
        // Feed Views
        [self setupFeedViews];
    }
}


#pragma mark - Feed Views

- (void)setupFeedViews {
    NSUInteger numberOfFeedViews = 3;
    
    CGFloat feedViewHeight = (self.view.bounds.size.height - 64)/numberOfFeedViews; // Note: 64.0 is to account for the status bar and navigation bar
    
    for (NSUInteger i = 0; i < numberOfFeedViews; i++) {
        GLKViewWithBounds *feedView = [self setupFeedViewWithFrame:CGRectMake(0.0, feedViewHeight*i, self.view.bounds.size.width, feedViewHeight)];
        [self.view addSubview:feedView];
        [self.feedViews addObject:feedView];
    }
}


- (GLKViewWithBounds *)setupFeedViewWithFrame:(CGRect)frame {
    GLKViewWithBounds *feedView = [[GLKViewWithBounds alloc] initWithFrame:frame context:self.eaglContext];
    feedView.enableSetNeedsDisplay = NO;
    
    // because the native video image from the back camera is in UIDeviceOrientationLandscapeLeft (i.e. the home button is on the right),
    // we need to apply a clockwise 90 degree transform so that we can draw the video preview as if we were in a landscape-oriented view;
    // if you're using the front camera and you want to have a mirrored preview (so that the user is seeing themselves in the mirror),
    // you need to apply an additional horizontal flip (by concatenating CGAffineTransformMakeScale(-1.0, 1.0) to the rotation transform)
    feedView.transform = CGAffineTransformMakeRotation(M_PI_2);
    feedView.frame = frame;
    
    // bind the frame buffer to get the frame buffer width and height;
    // the bounds used by CIContext when drawing to a GLKView are in pixels (not points),
    // hence the need to read from the frame buffer's width and height;
    // in addition, since we will be accessing the bounds in another queue (_captureSessionQueue),
    // we want to obtain this piece of information so that we won't be
    // accessing _videoPreviewView's properties from another thread/queue
    [feedView bindDrawable];
    
    feedView.viewBounds = CGRectMake(0.0, 0.0, feedView.drawableWidth, feedView.drawableHeight);
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CGAffineTransform transform = CGAffineTransformMakeRotation(M_PI_2);
        
        feedView.transform = transform;
        feedView.frame = frame;
    });
    
    return feedView;
}


#pragma mark - Contexts and Sessions

- (void)setupContexts {
    // setup the GLKView for video/image preview
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    // create the CIContext instance, note that this must be done after _videoPreviewView is properly set up
    _ciContext = [CIContext contextWithEAGLContext:_eaglContext
                                           options:@{kCIContextWorkingColorSpace : [NSNull null]} ];
}


- (void)setupSession {
    if (_captureSession)
        return;
    
    dispatch_async(_captureSessionQueue, ^(void) {
        NSError *error = nil;
        
        // get the input device and also validate the settings
        NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        
        AVCaptureDevice *_videoDevice = nil;
        
        if (!_videoDevice) {
            _videoDevice = [videoDevices objectAtIndex:0];
        }
        
        // obtain device input
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:_videoDevice error:&error];
        if (!videoDeviceInput)
        {
            [self _showAlertViewWithMessage:[NSString stringWithFormat:@"Unable to obtain video device input, error: %@", error]];
            return;
        }
        
        
        // obtain the preset and validate the preset
        NSString *preset = AVCaptureSessionPresetMedium;
        
        if (![_videoDevice supportsAVCaptureSessionPreset:preset])
        {
            [self _showAlertViewWithMessage:[NSString stringWithFormat:@"Capture session preset not supported by video device: %@", preset]];
            return;
        }
        
        // CoreImage wants BGRA pixel format
        NSDictionary *outputSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : [NSNumber numberWithInteger:kCVPixelFormatType_32BGRA]};
        
        // create the capture session
        _captureSession = [[AVCaptureSession alloc] init];
        _captureSession.sessionPreset = preset;
        
        // create and configure video data output
        
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        videoDataOutput.videoSettings = outputSettings;
        [videoDataOutput setSampleBufferDelegate:self queue:_captureSessionQueue];
        
        // begin configure capture session
        [_captureSession beginConfiguration];
        
        if (![_captureSession canAddOutput:videoDataOutput])
        {
            [self _showAlertViewWithMessage:@"Cannot add video data output"];
            _captureSession = nil;
            return;
        }
        
        // connect the video device input and video data and still image outputs
        [_captureSession addInput:videoDeviceInput];
        [_captureSession addOutput:videoDataOutput];
        
        [_captureSession commitConfiguration];
        
        // then start everything
        [_captureSession startRunning];
    });
}


#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    
    // update the video dimensions information
    _currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDesc);
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:(CVPixelBufferRef)imageBuffer options:nil];
    
    CGRect sourceExtent = sourceImage.extent;
    
    CGFloat sourceAspect = sourceExtent.size.width / sourceExtent.size.height;
    
    for (GLKViewWithBounds *feedView in self.feedViews) {
        
        CGFloat previewAspect = feedView.viewBounds.size.width  / feedView.viewBounds.size.height;
        
        // we want to maintain the aspect radio of the screen size, so we clip the video image
        CGRect drawRect = sourceExtent;
        if (sourceAspect > previewAspect) {
            // use full height of the video image, and center crop the width
            drawRect.origin.x += (drawRect.size.width - drawRect.size.height * previewAspect) / 2.0;
            drawRect.size.width = drawRect.size.height * previewAspect;
        } else {
            // use full width of the video image, and center crop the height
            drawRect.origin.y += (drawRect.size.height - drawRect.size.width / previewAspect) / 2.0;
            drawRect.size.height = drawRect.size.width / previewAspect;
        }
        
        [feedView bindDrawable];
        
        if (_eaglContext != [EAGLContext currentContext]) {
            [EAGLContext setCurrentContext:_eaglContext];
        }
        
        // clear eagl view to grey
        glClearColor(0.5, 0.5, 0.5, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        
        // set the blend mode to "source over" so that CI will use that
        glEnable(GL_BLEND);
        glBlendFunc(GL_ONE, GL_ONE_MINUS_SRC_ALPHA);
        
        if (sourceImage) {
            [_ciContext drawImage:sourceImage inRect:feedView.viewBounds fromRect:drawRect];
        }
        
        [feedView display];
    }
}


#pragma mark - Misc

- (void)_showAlertViewWithMessage:(NSString *)message {
    [self _showAlertViewWithMessage:message title:@"Error"];
}


- (void)_showAlertViewWithMessage:(NSString *)message title:(NSString *)title {
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                        message:message
                                                       delegate:nil
                                              cancelButtonTitle:@"Dismiss"
                                              otherButtonTitles:nil];
        [alert show];
    });
}

@end
