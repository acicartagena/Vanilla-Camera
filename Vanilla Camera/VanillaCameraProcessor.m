//
//  VanillaCameraProcessor.m
//  Vanilla Camera
//
//  Created by Angela Cartagena on 4/25/14.
//
//

#import "VanillaCameraProcessor.h"

//OUTPUT MODE
//#define MOVIE
#define VIDEODATA

@interface VanillaCameraProcessor ()

@property (strong, nonatomic) AVCaptureDeviceInput *videoInput;
@property (strong, nonatomic) AVCaptureDeviceInput *audioInput;

@property (strong, nonatomic) AVCaptureVideoDataOutput *videoOutput;
@property (strong, nonatomic) AVCaptureConnection *videoConnection;

@property (strong, nonatomic) AVCaptureMovieFileOutput *movieOutput;
@property (strong, nonatomic) AVAssetWriter *assetWriter;
@property (strong, nonatomic) AVAssetWriterInput *assetWriterVideoInput;

@property (nonatomic) dispatch_queue_t sessionQueue;
@property (nonatomic) dispatch_queue_t writerQueue;

@property (strong, nonatomic) NSURL *videoURL;
@end

@implementation VanillaCameraProcessor

- (instancetype)init
{
    self = [super init];
    if (self){
        [self.session setSessionPreset:AVCaptureSessionPresetMedium];
    }
    return self;
}

#pragma mark - lazy load properties
- (AVCaptureSession *)session
{
    if (!_session){
        _session = [[AVCaptureSession alloc] init];
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

- (AVCaptureMovieFileOutput *)movieOutput
{
    if (!_movieOutput){
        _movieOutput = [[AVCaptureMovieFileOutput alloc] init];
    }
    return _movieOutput;
}

#pragma mark - setup
- (void)setupAssetWriter
{
    
    NSDictionary *videoCompressionSettings = @{AVVideoCodecKey:AVVideoCodecH264,
                                               AVVideoHeightKey:@(480),
                                               AVVideoWidthKey:@(640),
                                               AVVideoCompressionPropertiesKey:@{AVVideoAverageBitRateKey:@(11.4),     AVVideoMaxKeyFrameIntervalKey:@(30)}};
    NSError *error;
    self.videoURL = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@",[NSDate date]] stringByAppendingPathExtension:@"mov"]]];
    self.assetWriter = [[AVAssetWriter alloc] initWithURL:self.videoURL fileType:(NSString *)kUTTypeMPEG4 error:&error];
    
    if (error){
        NSLog(@"error in creating asset writer: %@",error.localizedDescription);
    }
    
    if ([self.assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]){
        self.assetWriterVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
        self.assetWriterVideoInput.expectsMediaDataInRealTime = YES;
        if ([self.assetWriter canAddInput:self.assetWriterVideoInput]){
            [self.assetWriter addInput:self.assetWriterVideoInput];
        }else{
            NSLog(@"error in adding asset writer input");
        }
    }
    
}

#pragma mark - camera public api
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
#endif
    });
    
}

- (void)setupPreviewWithView:(UIView *)previewView
{
    dispatch_async(dispatch_get_main_queue(), ^{
        CALayer *previewLayer = previewView.layer;
        AVCaptureVideoPreviewLayer *preview = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.session];
        
        //fix for preview not showing. set preview frame
        preview.frame = previewLayer.bounds;
        
        [previewLayer addSublayer:preview];
    });
}

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
        [self setupAssetWriter];
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
            NSLog(@"%s: asset writer status: %i",__PRETTY_FUNCTION__, self.assetWriter.status);
        }
        
//        [self.assetWriter.inputs enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
//            AVAssetWriterInput *input = (AVAssetWriterInput *)obj;
//            [input markAsFinished];
//        }];
        [self.assetWriter finishWritingWithCompletionHandler:^{
            self.assetWriter = nil;
        }];
    });
#endif
}

#pragma mark - private methods
- (void)saveToAssetsLibrary
{
    ALAssetsLibrary* library = [[ALAssetsLibrary alloc] init];
    [library writeVideoAtPathToSavedPhotosAlbum:self.videoURL completionBlock:^(NSURL *assetURL, NSError *error) {
        if (error){
            NSLog(@"error: %@",error.localizedDescription);
        }else{
            [[NSFileManager defaultManager] removeItemAtURL:self.videoURL error:&error];
        }
        self.assetWriter = nil;
    }];
}

#pragma mark - File Output Delegate
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
#endif

#pragma mark - AVCaptureVideoDataOutput delegate methods
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    if (!self.assetWriter || !self.isRecording){
        return;
    }
    if ([connection isEqual:self.videoConnection]){
        CFRetain(sampleBuffer);
        [self writeSampleBuffer:sampleBuffer ofType:AVMediaTypeVideo];
        CFRelease(sampleBuffer);
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    NSLog(@"asset writer drop");
}

- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
    NSLog(@"%s",__PRETTY_FUNCTION__);
	if ( self.assetWriter.status == AVAssetWriterStatusUnknown ) {
        NSLog(@"%s: assetwriter status: unknown",__PRETTY_FUNCTION__);
        if ([self.assetWriter startWriting]) {
			[self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
		}
		else {
            NSLog(@"error");
		}
	}
	
	if ( self.assetWriter.status == AVAssetWriterStatusWriting ) {
        NSLog(@"%s: assetwriter status: writing",__PRETTY_FUNCTION__);
		if (mediaType == AVMediaTypeVideo) {
			if (self.assetWriterVideoInput.readyForMoreMediaData) {
				if (![self.assetWriterVideoInput appendSampleBuffer:sampleBuffer]) {
					NSLog(@"error");
				}
			}
		}
        //		else if (mediaType == AVMediaTypeAudio) {
        //			if (assetWriterAudioIn.readyForMoreMediaData) {
        //				if (![assetWriterAudioIn appendSampleBuffer:sampleBuffer]) {
        //					[self showError:[assetWriter error]];
        //				}
        //			}
        //		}
	}
}



@end
