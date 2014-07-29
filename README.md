Introduction
===

I ran into the problem of needing to have multiple live camera previews displayed on a view, at the same time. After finding no viable solutions online and through much work, I present two different, but equally useful, solutions:

1. CAReplicatorLayer
===
The first option is to use a **[CAReplicatorLayer](https://developer.apple.com/library/ios/documentation/GraphicsImaging/Reference/CAReplicatorLayer_class/Reference/Reference.html)** to duplicate the layer automatically. As the docs say, it will automatically create "...a specified number of copies of its sublayers (the source layer), each copy potentially having geometric, temporal and color transformations applied to it." 

This is super useful if there isn't a lot of interaction with the live previews besides simple geometric or color transformations (Think Photo Booth). I have most often seen the CAReplicatorLayer used as a way to create the 'reflection' effect.

Here is some sample code to replicate a CACaptureVideoPreviewLayer:

###Init AVCaptureVideoPreviewLayer

    AVCaptureVideoPreviewLayer *previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
    [previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    [previewLayer setFrame:CGRectMake(0.0, 0.0, self.view.bounds.size.width, self.view.bounds.size.height / 4)];

###Init CAReplicatorLayer and set properties
*Note: This will replicate the live preview layer **four** times.*
    
    NSUInteger replicatorInstances = 4;

    CAReplicatorLayer *replicatorLayer = [CAReplicatorLayer layer];
    replicatorLayer.frame = CGRectMake(0, 0, self.view.bounds.size.width, self.view.bounds.size.height / replicatorInstances);
    replicatorLayer.instanceCount = instances;
    replicatorLayer.instanceTransform = CATransform3DMakeTranslation(0.0, self.view.bounds.size.height / replicatorInstances, 0.0);
    
    
###Add Layers

*Note: From my experience you need to add the layer you want to replicate to the CAReplicatorLayer as a sublayer.*

    [replicatorLayer addSublayer:previewLayer];
    [self.view.layer addSublayer:replicatorLayer];

##Downsides
A downside to using CAReplicatorLayer is that it handles all placement of the layer replications. So it will apply any set transformations to each instance and and it will all be contained within itself. *E.g. There would be no way to have a replication of a AVCaptureVideoPreviewLayer on two separate cells.*

<br>
2. Manually Rendering SampleBuffer
===

This method, albeit a tad more complex, solves the above mentioned downside of CAReplicatorLayer. By manually rendering the live previews, you are able to render as many views as you want. Granted, performance might be affected.

*Note: There might be other ways to render the SampleBuffer but I chose OpenGL because of its performance. Code was inspired and altered from [CIFunHouse](https://developer.apple.com/library/ios/samplecode/CIFunHouse/Introduction/Intro.html).*

Here is how I implemented it:

##2.1 Contexts and Session

### Setup OpenGL and CoreImage Context
    _eaglContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    // Note: must be done after the all your GLKViews are properly set up
    _ciContext = [CIContext contextWithEAGLContext:_eaglContext
                                           options:@{kCIContextWorkingColorSpace : [NSNull null]}];


###Dispatch Queue
This queue will be used for the session and delegate.

    self.captureSessionQueue = dispatch_queue_create("capture_session_queue", NULL);

###Init your AVSession & AVCaptureVideoDataOutput
*Note: I have removed all device capability checks to make this more readable.*

	dispatch_async(self.captureSessionQueue, ^(void) {
		NSError *error = nil;
        
        // get the input device and also validate the settings
        NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
        
        AVCaptureDevice *_videoDevice = nil;
        if (!_videoDevice) {
            _videoDevice = [videoDevices objectAtIndex:0];
        }
        
        // obtain device input
        AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:self.videoDevice error:&error];
        
        // obtain the preset and validate the preset
        NSString *preset = AVCaptureSessionPresetMedium;
        
        // CoreImage wants BGRA pixel format
        NSDictionary *outputSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
        
        // create the capture session
        self.captureSession = [[AVCaptureSession alloc] init];
        self.captureSession.sessionPreset = preset;
		:
        
*Note: The following code is the 'magic code'. It is where we are create and add a DataOutput to the AVSession so we can intercept the camera frames using the delegate. This is the breakthrough I needed to figure out how to solve the problem.*

		:
        // create and configure video data output
        AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        videoDataOutput.videoSettings = outputSettings;
        [videoDataOutput setSampleBufferDelegate:self queue:self.captureSessionQueue];
        
        // begin configure capture session
        [self.captureSession beginConfiguration];
        
        // connect the video device input and video data and still image outputs
        [self.captureSession addInput:videoDeviceInput];
        [self.captureSession addOutput:videoDataOutput];
        
        [self.captureSession commitConfiguration];
        
        // then start everything
        [self.captureSession startRunning];
    });


##2.2 OpenGL Views
We are using GLKView to render our live previews. So if you want 4 live previews, then you need 4 GLKView.

	self.livePreviewView = [[GLKView alloc] initWithFrame:self.bounds context:self.eaglContext];
    self.livePreviewView = NO;
    
Because the native video image from the back camera is in UIDeviceOrientationLandscapeLeft (i.e. the home button is on the right), we need to apply a clockwise 90 degree transform so that we can draw the video preview as if we were in a landscape-oriented view; if you're using the front camera and you want to have a mirrored preview (so that the user is seeing themselves in the mirror), you need to apply an additional horizontal flip (by concatenating CGAffineTransformMakeScale(-1.0, 1.0) to the rotation transform)

    self.livePreviewView.transform = CGAffineTransformMakeRotation(M_PI_2);
    self.livePreviewView.frame = self.bounds;    
    [self addSubview: self.livePreviewView];
    
Bind the frame buffer to get the frame buffer width and height. The bounds used by CIContext when drawing to a GLKView are in pixels (not points), hence the need to read from the frame buffer's width and height.

    [self.livePreviewView bindDrawable];
    
In addition, since we will be accessing the bounds in another queue (_captureSessionQueue), we want to obtain this piece of information so that we won't be accessing _videoPreviewView's properties from another thread/queue.

    _videoPreviewViewBounds = CGRectZero;
    _videoPreviewViewBounds.size.width = _videoPreviewView.drawableWidth;
    _videoPreviewViewBounds.size.height = _videoPreviewView.drawableHeight;
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        CGAffineTransform transform = CGAffineTransformMakeRotation(M_PI_2);        

		// *Horizontally flip here, if using front camera.*

        self.livePreviewView.transform = transform;
        self.livePreviewView.frame = self.bounds;
    });

*Note: If you are using the front camera you can horizontally flip the live preview like this:*

	transform = CGAffineTransformConcat(transform, CGAffineTransformMakeScale(-1.0, 1.0));

##2.3 Delegate Implementation

After we have the Contexts, Sessions, and GLKViews set up we can now render to our views from the *AVCaptureVideoDataOutputSampleBufferDelegate* method captureOutput:didOutputSampleBuffer:fromConnection:

	- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
	{
    	CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    
	    // update the video dimensions information
	    self.currentVideoDimensions = CMVideoFormatDescriptionGetDimensions(formatDesc);
	    
	    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	    CIImage *sourceImage = [CIImage imageWithCVPixelBuffer:(CVPixelBufferRef)imageBuffer options:nil];
	    
	    CGRect sourceExtent = sourceImage.extent;
	    CGFloat sourceAspect = sourceExtent.size.width / sourceExtent.size.height;
	    
You will need to have a reference to each GLKView and it's videoPreviewViewBounds. For easiness, I will assume they are both contained in a UICollectionViewCell. You will need to alter this for your own use-case. 

	    for(CustomLivePreviewCell *cell in self.livePreviewCells) {
	        CGFloat previewAspect = cell.videoPreviewViewBounds.size.width  / cell.videoPreviewViewBounds.size.height;
	        
	        // To maintain the aspect radio of the screen size, we clip the video image
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
	        
	        [cell.livePreviewView bindDrawable];
	        
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
	            [_ciContext drawImage:sourceImage inRect:cell.videoPreviewViewBounds fromRect:drawRect];
	        }
	        
	        [cell.livePreviewView display];
   		}
	}

This solution lets you have as many live previews as you want using OpenGL to render the buffer of images received from the AVCaptureVideoDataOutputSampleBufferDelegate.

3. Sample Code
===

This is a quick and dirty project I threw together to show how to use both previously detailed soultions.


