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
        
        dispatch_queue_t queue;
        queue = dispatch_queue_create("Vanilla Camera Video Output Queue", DISPATCH_QUEUE_SERIAL);
        [_videoOutput setSampleBufferDelegate:self queue:queue];
        
        [_videoOutput setVideoSettings:@{(NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)}];
        self.videoConnection = [_videoOutput connectionWithMediaType:AVMediaTypeVideo];
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

- (AVAssetWriter *)assetWriter
{
    if (!_assetWriter){
        NSDictionary *videoCompressionSettings = @{AVVideoCodecKey: AVVideoCodecH264,
                                                   AVVideoCompressionPropertiesKey: @{AVVideoAverageBitRateKey:@(11.4),     AVVideoMaxKeyFrameIntervalKey: @(30)}};
        NSError *error;
        NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@",[NSDate date]]stringByAppendingPathExtension:@"mov"]];
		_assetWriter = [[AVAssetWriter alloc] initWithURL:[NSURL URLWithString:outputFilePath] fileType:(NSString *)kUTTypeMPEG4 error:&error];
		if (error){
            NSLog(@"error in creating asset writer: %@",error.localizedDescription);
        }
        
        if ([_assetWriter canApplyOutputSettings:videoCompressionSettings forMediaType:AVMediaTypeVideo]){
            self.assetWriterVideoInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeVideo outputSettings:videoCompressionSettings];
            self.assetWriterVideoInput.expectsMediaDataInRealTime = YES;
            if ([_assetWriter canAddInput:self.assetWriterVideoInput]){
                [_assetWriter addInput:self.assetWriterVideoInput];
            }else{
                NSLog(@"error in adding asset writer input");
            }
        }
    }
    return _assetWriter;
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
    dispatch_async(self.sessionQueue, ^{
#ifdef MOVIE
        if (![self.movieOutput isRecording]){
            NSString *outputFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSString stringWithFormat:@"%@",[NSDate date]]stringByAppendingPathExtension:@"mov"]];
			[self.movieOutput startRecordingToOutputFileURL:[NSURL fileURLWithPath:outputFilePath] recordingDelegate:self];
        }
#else
        
#endif
    });
}

- (void)stopRecording
{
    self.recording = NO;
    dispatch_async(self.sessionQueue, ^{
#ifdef MOVIE
        if ([self.movieOutput isRecording]){
            [self.movieOutput stopRecording];
        }
#else
        self.assetWriter = nil;
#endif
    });
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
    dispatch_async(self.writerQueue, ^{
        if (!self.assetWriter || !self.isRecording){
            return;
        }
        
        if ([connection isEqual:self.videoConnection]){
            
        }
    });
}

- (void) writeSampleBuffer:(CMSampleBufferRef)sampleBuffer ofType:(NSString *)mediaType
{
	if ( self.assetWriter.status == AVAssetWriterStatusUnknown ) {
		
        if ([self.assetWriter startWriting]) {
			[self.assetWriter startSessionAtSourceTime:CMSampleBufferGetPresentationTimeStamp(sampleBuffer)];
		}
		else {
            NSLog(@"error");
		}
	}
	
	if ( self.assetWriter.status == AVAssetWriterStatusWriting ) {
		
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
