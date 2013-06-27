//
//  ViewController.h
//  Pocket Reader
//
//  Created by Gabriel Borges Fernandes on 4/28/13.
//  Copyright (c) 2013 Gabriel Borges Fernandes. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "Tesseract.h"

@interface ViewController : UIViewController <AVCaptureVideoDataOutputSampleBufferDelegate> {
    
	AVCaptureSession *captureSession;
    AVCaptureDevice *captureDevice;
    AVCaptureVideoDataOutput* videoOutput;
    AVCaptureVideoPreviewLayer *captureLayer;
    
    int camera;
    NSString *_qualityPreset;
    BOOL captureGrayscale;
    BOOL recognize;
   
}

@property (strong, nonatomic) IBOutlet UIView *recordPreview;
@property (strong, nonatomic) AVCaptureVideoPreviewLayer *captureLayer;
@property (strong, nonatomic) AVCaptureDevice *captureDevice;
@property (strong, nonatomic) AVCaptureVideoDataOutput *videoOutput;
@property (strong, nonatomic) AVCaptureSession *captureSession;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *um;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *dois;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *tres;
@property (nonatomic) int camera;
@property (weak, nonatomic) NSString * const qualityPreset;
@property (nonatomic) BOOL captureGrayscale;

- (IBAction) apertouUm:(id)sender;
- (IBAction) apertouDois:(id)sender;
- (IBAction) apertouTres:(id)sender;

@end
