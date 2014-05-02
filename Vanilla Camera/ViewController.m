//
//  ViewController.m
//  Vanilla Camera
//
//  Created by Angela Cartagena on 4/25/14.
//
//

#import "ViewController.h"
#import "VanillaCameraProcessor.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UIView *previewView;
@property (strong, nonatomic) VanillaCameraProcessor *camera;

@end

@implementation ViewController

#pragma mark - vc lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    [self.camera setupCamera];
    //setup preview (should be done on main queue)
    [self.camera setupPreviewWithView:self.previewView];
    
//    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tap:)];
//    tapGesture.numberOfTapsRequired = 1;
//    tapGesture.numberOfTouchesRequired = 1;
//    [self.view addGestureRecognizer:tapGesture];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self.camera startCameraCapture];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [self.camera stopCameraCapture];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    
//    [self.camera updateView:self.previewView orientation:toInterfaceOrientation];
}

#pragma mark - lazy load properties
- (VanillaCameraProcessor *)camera
{
    if (!_camera){
        _camera = [[VanillaCameraProcessor alloc] init];
    }
    return _camera;
}

#pragma mark - touch
- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!self.camera.isRecording){
        [self.camera startRecording];
    }
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (self.camera.isRecording){
        [self.camera stopRecording];
    }
}

- (IBAction)toggleCamera:(id)sender
{
    [self.camera toggleCamera];
}

@end
