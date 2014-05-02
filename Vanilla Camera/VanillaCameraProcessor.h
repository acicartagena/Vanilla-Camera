//
//  VanillaCameraProcessor.h
//  Vanilla Camera
//
//  Created by Angela Cartagena on 4/25/14.
//
//

#import <Foundation/Foundation.h>

#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <MobileCoreServices/MobileCoreServices.h>

#define kVanillaCamRecordingStarted @"Vanilla Camera Recording Started"
#define kVanillaCamRecordingStopped @"Vanilla Camera Recording Stopped"
#define kVanillaCamFileFinished @"Vanilla Camera File Finished"

//Session Output Mode: AVCaptureMovieFileOutput or AVCaptureVideoDataOutput&AVCaptureAudioDataOutput
//#define MOVIE
#define VIDEODATA

//DEBUG
//#define LANDSCAPE_IS_WORKING

@protocol VanillaCameraProcessorDelegate <NSObject>
@optional
- (void)pixelBufferReadyForDisplay:(CVPixelBufferRef)pixelBuffer;
@end

#ifdef MOVIE
@interface VanillaCameraProcessor : NSObject<AVCaptureFileOutputRecordingDelegate>
#else
@interface VanillaCameraProcessor : NSObject<AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate>
#endif

@property (strong, nonatomic) AVCaptureSession *session;
@property (weak, nonatomic) id<VanillaCameraProcessorDelegate> delegate;
@property (nonatomic, getter = isRecording) BOOL recording;

- (void)setupCamera;
- (void)setupPreviewWithView:(UIView *)previewView;

- (void)startCameraCapture;
- (void)stopCameraCapture;

- (void)startRecording;
- (void)stopRecording;

- (void)toggleCamera;

#ifdef LANDSCAPE_IS_WORKING
- (void)updateView:(UIView *)view orientation:(UIInterfaceOrientation)orientation;
#endif
@end
