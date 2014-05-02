//
//  VanillaCameraProcessor.m
//  Vanilla Camera
//
//  Created by Angela Cartagena on 4/25/14.
//
//
//TODO: (no order)
// check authorization for cameras
// include front and back camera
// add filters
// landscape


#import "VanillaCameraProcessor.h"

@interface VanillaCameraProcessor ()

@property (strong, nonatomic) AVCaptureDeviceInput *videoInput;
@property (strong, nonatomic) AVCaptureDeviceInput *audioInput;

@property (strong, nonatomic) AVCaptureVideoDataOutput *videoOutput;
@property (strong, nonatomic) AVCaptureAudioDataOutput *audioOutput;

@property (strong, nonatomic) AVCaptureConnection *videoConnection;
@property (strong, nonatomic) AVCaptureConnection *audioConnection;

@property (strong, nonatomic) AVCaptureMovieFileOutput *movieOutput;

@property (strong, nonatomic) AVAssetWriter *assetWriter;
@property (strong, nonatomic) AVAssetWriterInput *assetWriterVideoInput;
@property (strong, nonatomic) AVAssetWriterInput *assetWriterAudioInput;

@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) dispatch_queue_t writerQueue;

@property (strong, nonatomic) NSURL *videoURL;

@property (nonatomic, getter = isAssetWriterVideoOutputSetupFinished) BOOL assetWriterVideoOutputSetupFinished;
@property (nonatomic, getter = isAssetWriterAudioOutputSetupFinished) BOOL assetWriterAudioOutputSetupFinished;

@property (weak, nonatomic) AVCaptureVideoPreviewLayer *previewLayer;

@end

@implementation VanillaCameraProcessor

- (instancetype)init
{
    self = [super init];
    if (self){
        [self session];
    }
    return self;
}

#pragma mark - lazy load properties
- (AVCaptureSession *)session
{
    if (!_session){
        _session = [[AVCaptureSession alloc] init];
        [_session setSessionPreset:AVCaptureSessionPreset640x480];
        self.sessionQueue = dispatch_queue_create("setup session queue", DISPATCH_QUEUE_SERIAL);
    }
    return _session;
}

- (AVCaptureDeviceInput *)videoInput
{
    if (!_videoInput){
        NSError *error = nil;
        AVCaptureDevice *videoDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] firstObject];
        _videoInput = videoDevice ? [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error]:nil;
    }
    return _videoInput;
}

- (AVCaptureDeviceInput *)audioInput
{
    if (!_audioInput){
        NSError *error = nil;
        AVCaptureDevice *audioDevice = [[AVCaptureDevice devicesWithMediaType:AVMediaTypeAudio] firstObject];
        _audioInput = audioDevice ? [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error]:nil;
    }
    return _audioInput;
}

- (AVCaptureVideoDataOutput *)videoOutput
{
    if (!_videoOutput){
        _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
        [_videoOutput setAlwaysDiscardsLateVideoFrames:YES];
        
        self.writerQueue = dispatch_queue_create("writer queue", DISPATCH_QUEUE_SERIAL);
        [_videoOutput setSampleBufferDelegate:self queue:self.writerQueue];
        
        [_videoOutput setVideoSettings:@{(NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];
    }
    return _videoOutput;
}

- (AVCaptureAudioDataOutput *)audioOutput
{
    if (!_audioOutput){
        _audioOutput = [[AVCaptureAudioDataOutput alloc] init];
        dispatch_queue_t audioWriterQueue = dispatch_queue_create("audio writer queue", DISPATCH_QUEUE_SERIAL);
        [_audioOutput setSampleBufferDelegate:self queue:audioWriterQueue];
    }
    return _audioOutput;
}

- (AVCaptureMovieFileOutput *)movieOutput
{
    if (!_movieOutput){
        _movieOutput = [[AVCaptureMovieFileOutput alloc] init];
    }
    return _movieOutput;
}

- (AVAssetWriter *)assetWriter
{
    if (!_assetWriter){
        NSError *error;
        self.videoURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@",[NSDate date]] stringByAppendingPathExtension:@"mp4"]]];
        _assetWriter = [[AVAssetWriter alloc] initWithURL:self.videoURL fileType:(NSString *)kUTTypeMPEG4 error:&error];
        
        if (error){
            NSLog(@"error in creating asset writer: %@",error.localizedDescription);
        }
    }
    return _assetWriter;
}

#pragma mark - setup
- (void)setupCamera
{
    dispatch_async(self.sessionQueue, ^{
        
        //TODO: check device authorization
        
        //video input
        if ([self.session canAddInput:self.videoInput]){
            [self.session addInput:self.videoInput];
        }
        
        //audio input
        if ([self.session canAddInput:self.audioInput]){
            [self.session addInput:self.audioInput];
        }
        
        //video output
#ifdef MOVIE
        if ([self.session canAddOutput:self.movieOutput]){
            [self.session addOutput:self.movieOutput];
            
            //video stabilization
            AVCaptureConnection *connection = [self.movieOutput connectionWithMediaType:AVMediaTypeVideo];
			if ([connection isVideoStabilizationSupported])
				[connection setEnablesVideoStabilizationWhenAvailable:YES];
        }
#else
        if ([self.session canAddOutput:self.videoOutput]){
            [self.session addOutput:self.videoOutput];
            
            self.videoConnection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
            if ([self.videoConnection isVideoStabilizationSupported]){
				[self.videoConnection setEnablesVideoStabilizationWhenAvailable:YES];
            }
        }
    
        //audio output
        if ([self.session canAddOutput:self.audioOutput]){
            [self.session addOutput:self.audioOutput];
            
            self.audioConnection = [self.audioOutput connectionWithMediaType:AVMediaTypeAudio];
        }
#endif
    });
}

- (void)setupPreviewWithView:(UIView *)previewView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        CALayer *previewLayer = previewView.layer;
        
        AVCaptureVideoPreviewLayer *preview = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
//        preview.videoGravity = AVLayerVideoGravityResizeAspect;
        //fix for preview not showing. set preview frame
        preview.frame = previewView.bounds;
        [previewLayer addSublayer:preview];
    });
}

#ifdef LANDSCAPE_IS_WORKING
- (void)updateView:(UIView *)view orientation:(UIInterfaceOrientation)orientation
{
    dispatch_async(dispatch_get_main_queue(), ^{
    for (CALayer *sublayer in view.layer.sublayers) {
        if ([sublayer isKindOfClass:[AVCaptureVideoPreviewLayer class]]){
            AVCaptureVideoPreviewLayer *previewLayer = (AVCaptureVideoPreviewLayer *)sublayer;
            previewLayer.frame = view.bounds;
        }
    }
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
            self.videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            self.videoConnection.videoOrientation = AVCaptureVideoOrientationLandscapeLeft;
            break;
        case UIInterfaceOrientationLandscapeRight:
            self.videoConnection.videoOrientation = AVCaptureVideoOrientationLandscapeRight;
        default:
            break;
    }
    });
}
#endif

- (void)setupAssetWriterVideoCompression:(CMFormatDescriptionRef)formatDescription
{
    float bitsPerPixel;
    int bitsPerSecond;
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription);
    int numPixels = dimensions.width *dimensions.height;
    
    // Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
//    bitsPerPixel = numPixels < (640*480) ? 4.05: 11.4;
    bitsPerPixel = 3.05f;       //lower bitrate for more compressed files
	bitsPerSecond = numPixels * bitsPerPixel;
    
    NSLog(@"video orientation: %i vs portraint orientation: %i",(int)self.videoConnection.videoOrientation, (int)AVCaptureVideoOrientationPortrait);
    NSLog(@"height: %i width:%i",dimensions.height,dimensions.width);
    NSDictionary *videoCompressionSettings = @{AVVideoCodecKey:AVVideoCodecH264,
                                               AVVideoHeightKey:@(dimensions.height),
                                               AVVideoWidthKey:@(dimensions.width),
                                               AVVideoCompressionPropertiesKey:@{AVVideoAverageBitRateKey:@(bitsPerSecond),     AVVideoMaxKeyFrameIntervalKey:@(30)}};
    //compress later
//    NSDictionary *videoCompressionSettings = @{AVVideoCodecKey:AVVideoCodecH264,
//                                               AVVideoHeightKey:@(dimensions.height),
//                                               AVVideoWidthKey:@(dimensions.width)};

    
    if ([self.assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]){
        self.assetWriterVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
        self.assetWriterVideoInput.expectsMediaDataInRealTime = YES;
        self.assetWriterVideoInput.transform = [self transformFromCurrentVideoOrientationToOrientation:AVCaptureVideoOrientationPortrait];
        if ([self.assetWriter canAddInput:self.assetWriterVideoInput]){
            [self.assetWriter addInput:self.assetWriterVideoInput];
        }else{
            NSLog(@"error in adding asset writer input video");
        }
    }
    
}

- (void)setupAssetWriterAudioCompression:(CMFormatDescriptionRef)formatDescription
{
    const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription);
    size_t aclSize = 0;
    const AudioChannelLayout *currentChannelLayout = CMAudioFormatDescriptionGetChannelLayout(formatDescription, &aclSize);
    NSData *currentChannelLayoutData = nil;
    
    // AVChannelLayoutKey must be specified, but if we don't know any better give an empty data and let AVAssetWriter decide.
	if ( currentChannelLayout && aclSize > 0 )
		currentChannelLayoutData = [NSData dataWithBytes:currentChannelLayout length:aclSize];
	else
		currentChannelLayoutData = [NSData data];
    NSDictionary *audioCompressionSettings = @{AVFormatIDKey: @(kAudioFormatMPEG4AAC),
                                               AVSampleRateKey: @(asbd->mSampleRate),
                                               AVEncoderBitRatePerChannelKey: @(64000),
                                               AVNumberOfChannelsKey: @(asbd->mChannelsPerFrame),
                                               AVChannelLayoutKey: currentChannelLayoutData};
    
    if ([self.assetWriter canApplyOutputSettings:audioCompressionSettings forMediaType:AVMediaTypeAudio]){
        self.assetWriterAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:audioCompressionSettings];
        self.assetWriterAudioInput.expectsMediaDataInRealTime = YES;
        
        if ([self.assetWriter canAddInput:self.assetWriterAudioInput]){
            [self.assetWriter addInput:self.assetWriterAudioInput];
        }else{
            NSLog(@"error in adding asset writer input audio");
        }
        
    }
}

- (CGAffineTransform)transformFromCurrentVideoOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
	CGAffineTransform transform = CGAffineTransformIdentity;
    
	// Calculate offsets from an arbitrary reference orientation (portrait)
	CGFloat orientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:orientation];
	CGFloat videoOrientationAngleOffset = [self angleOffsetFromPortraitOrientationToOrientation:self.videoConnection.videoOrientation];
	
	// Find the difference in angle between the passed in orientation and the current video orientation
	CGFloat angleOffset = orientationAngleOffset - videoOrientationAngleOffset;
	transform = CGAffineTransformMakeRotation(angleOffset);
	
	return transform;
}

- (CGFloat)angleOffsetFromPortraitOrientationToOrientation:(AVCaptureVideoOrientation)orientation
{
	CGFloat angle = 0.0;
	
	switch (orientation) {
		case AVCaptureVideoOrientationPortrait:
			angle = 0.0;
			break;
		case AVCaptureVideoOrientationPortraitUpsideDown:
			angle = M_PI;
			break;
		case AVCaptureVideoOrientationLandscapeRight:
			angle = -M_PI_2;
			break;
		case AVCaptureVideoOrientationLandscapeLeft:
			angle = M_PI_2;
			break;
		default:
			break;
	}
    
	return angle;
}

#pragma mark - camera controls


- (void)startCameraCapture
{
    dispatch_async(self.sessionQueue, ^{
        [self.session startRunning];
    });
}

- (void)stopCameraCapture
{
    dispatch_async(self.sessionQueue, ^{
        [self.session stopRunning];
    });
}

- (void)startRecording
{
    self.recording = YES;
#ifdef MOVIE
    dispatch_async(self.sessionQueue, ^{
        if (![self.movieOutput isRecording]){
            NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@",[NSDate date]]stringByAppendingPathExtension:@"mov"]];
            [self.movieOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
        }
    });
#else
    dispatch_async(self.writerQueue, ^{
        [self assetWriter];
        [[NSNotificationCenter defaultCenter] postNotificationName:kVanillaCamRecordingStarted object:self];
    });
#endif
}

- (void)stopRecording
{
    self.recording = NO;

#ifdef MOVIE
    dispatch_async(self.sessionQueue, ^{
        if ([self.movieOutput isRecording]){
            [self.movieOutput stopRecording];
        }
    });
#else
    dispatch_async(self.writerQueue, ^{
        
        if (self.assetWriter.status == AVAssetWriterStatusUnknown || self.assetWriter.status == AVAssetWriterStatusFailed){
            self.assetWriter = nil;
            self.assetWriterVideoOutputSetupFinished = NO;
            NSLog(@"%s: asset writer status: %li",__PRETTY_FUNCTION__, (long)self.assetWriter.status);
        }
        
//        [self.assetWriter.inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//            AVAssetWriterInput *input = (AVAssetWriterInput *)obj;
//            [input markAsFinished];
//        }];
        [self.assetWriter finishWritingWithCompletionHandler:^{
            [self saveToAssetsLibrary];
            
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSError *error = nil;
            NSDictionary *fileDetails = [fileManager attributesOfItemAtPath:self.videoURL.path error:&error];
            NSLog(@"FILE SIZE: file size: %@",fileDetails[NSFileSize]);
            self.assetWriter = nil;
            self.assetWriterVideoOutputSetupFinished = NO;
            self.assetWriterAudioOutputSetupFinished = NO;
            [[NSNotificationCenter defaultCenter] postNotificationName:kVanillaCamRecordingStopped object:self];
        }];
        [[NSNotificationCenter defaultCenter] postNotificationName:kVanillaCamFileFinished object:self];
    });
#endif
}

- (void)updatePreivewView:(UIView *)preview orientation:(UIInterfaceOrientation)orientation
{
    [self.videoConnection setVideoOrientation:(AVCaptureVideoOrientation)orientation];
}

#pragma mark - output methods

- (void)saveToAssetsLibrary
{
    ALAssetsLibrary* library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:self.videoURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error){
            NSLog(@"error: %@",error.localizedDescription);
        }else{
//            [[NSFileManager defaultManager] removeItemAtURL:self.videoURL error:&error];
        }
        self.assetWriter = nil;
    }];
}

#pragma mark - file output delegate (AVCaptureMovieFileOutput)
#ifdef MOVIE
- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didStartRecordingToOutputFileAtURL:(NSURL *)fileURL fromConnections:(NSArray *)connections
{
    
}

- (void)captureOutput:(AVCaptureFileOutput *)captureOutput didFinishRecordingToOutputFileAtURL:(NSURL *)outputFileURL fromConnections:(NSArray *)connections error:(NSError *)error
{
	if (error)
		NSLog(@"capture error:%@", error);
    
    ALAssetsLibrary* library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:outputFileURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error){
            NSLog(@"error: %@",error.localizedDescription);
        }else{
            [[NSFileManager defaultManager] removeItemAtURL:outputFileURL error:&error];
        }
    }];
}

#else
#pragma mark - avcapturevideodataoutput delegate methods
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (!self.assetWriter || !self.isRecording){
        return;
    }
    CFRetain(sampleBuffer);
    if ([connection isEqual:self.videoConnection]){
        
        if (!self.isAssetWriterVideoOutputSetupFinished){
            CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
            [self setupAssetWriterVideoCompression:formatDescription];
            self.assetWriterVideoOutputSetupFinished = YES;
        }
        //only start writing once BOTH audio and video setup is finished (can't add asset writer inputs, once writing starts
        if (self.isAssetWriterAudioOutputSetupFinished && self.isAssetWriterVideoOutputSetupFinished){
            [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo];
        }
    }
    
    if ([connection isEqual:self.audioConnection]){
        if (!self.isAssetWriterAudioOutputSetupFinished){
            CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer);
            [self setupAssetWriterAudioCompression:formatDescription];
            self.assetWriterAudioOutputSetupFinished = YES;
        }
        
        if (self.isAssetWriterAudioOutputSetupFinished && self.isAssetWriterVideoOutputSetupFinished){
            [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeAudio];
        }
    }
    //don't forget to release buffer!
    CFRelease(sampleBuffer);
}

#pragma mark - buffer processing
- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
	if ( self.assetWriter.status == AVAssetWriterStatusUnknown ) {
        if ([self.assetWriter startWriting]) {
			[self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
		}else {
            NSLog(@"error: assetWriter start writing");
		}
	}
	
	if ( self.assetWriter.status == AVAssetWriterStatusWriting ) {
		if (mediaType == AVMediaTypeVideo && self.assetWriterVideoInput.readyForMoreMediaData) {
            if (![self.assetWriterVideoInput appendSampleBuffer:sampleBuffer]) {
                NSLog(@"error asset writer append sample buffer video");
            }
		}else if (mediaType == AVMediaTypeAudio && self.assetWriterAudioInput.readyForMoreMediaData) {
            if (![self.assetWriterAudioInput appendSampleBuffer:sampleBuffer]) {
                NSLog(@"error asset writer append sample buffer audio");
            }
        }
	}
}
#endif

@end
