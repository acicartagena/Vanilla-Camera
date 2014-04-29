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

//OUTPUT MODE
//#define MOVIE
#define VIDEODATA

@protocol VanillaCameraProcessorDelegate <NSObject>
@optional
- (void)pixelBufferReadyForDisplay:(CVPixelBufferRef)pixelBuffer;
@end

#ifdef MOVIE
@interface VanillaCameraProcessor : NSObject<AVCaptureFileOutputRecordingDelegate>
#else
@interface VanillaCameraProcessor : NSObject<AVCaptureVideoDataOutputSampleBufferDelegate>
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

- (void)updateView:(UIView *)view orientation:(UIInterfaceOrientation)orientation;

@end
