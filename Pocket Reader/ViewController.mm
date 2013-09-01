//
//  ViewController.m
//  Pocket Reader
//
//  Created by Gabriel Borges Fernandes on 4/28/13.
//  Copyright (c) 2013 Gabriel Borges Fernandes. All rights reserved.
//
//  Using part of code created by Robin Summerhill on 02/09/2011.
//  Copyright 2011 Aptogo Limited. All rights reserved.
//
//  Permission is given to use this source code file without charge in any
//  project, commercial or otherwise, entirely at your risk, with the condition
//  that any redistribution (in part or whole) of source code must retain
//  this copyright and permission notice. Attribution in compiled projects is
//  appreciated but not required.
//
//
#import "UIImage+OpenCV.h"
#import "ViewController.h"

@interface ViewController () {
    cv::Rect padrao;
}
@end

@implementation ViewController

@synthesize camera;
@synthesize captureGrayscale;
@synthesize qualityPreset;
@synthesize captureSession;
@synthesize captureDevice;
@synthesize videoOutput;
@synthesize captureLayer;
@synthesize stillImage;
@synthesize tesseract;


#pragma mark - Default:
- (void)viewDidLoad
{
    [super viewDidLoad];
    padrao.x = 50;
    padrao.y = 70;
    padrao.width = 233; //Create a rectangle for guide
    padrao.height = 319; // Note: "padrao" is portuguese for "default"
    self.qualityPreset = AVCaptureSessionPresetPhoto; //maximum quality
    captureGrayscale = NO; //Set color capture
    self.camera = -1; //Set back camera
    recognize = NO; //clean Recognize text flag
    isOpenCVOn = NO; //clean OpenCV Flag
    isTorchOn = NO; //clean Flash Flag
    
    threshold = 128;                        // set threshold stepper (for debug)
    [self.stepperOne setValue:threshold];
    [self.stepperOne setMaximumValue:255];
    [self.stepperOne setMinimumValue:0];
    n_erode_dilate = 1;                     // set errode_dilatate stepper (for debug)
    [self.stepperTwo setValue:n_erode_dilate];
    [self.stepperTwo setMaximumValue:255];
    [self.stepperTwo setMinimumValue:0];
    //[self.recordPreview setBounds:];
    [self createCaptureSessionForCamera:camera qualityPreset:qualityPreset grayscale:captureGrayscale]; //set camera and it view
    [captureSession startRunning]; //start the camera capturing
    
}

- (void)didReceiveMemoryWarning
{
    isOpenCVOn = NO;  //disable OpenCV processing and let ARC clean the memory
    [self performSelector:@selector(timerFireMethod:) withObject:nil afterDelay:2.0]; //after 2 seconds turn openCV on again
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.

}

#pragma mark - Buttons:

- (IBAction)apertouUm:(id)sender
{
    isTorchOn = !isTorchOn; //Invert the flash state
}

- (IBAction)apertouDois:(id)sender
{
    UIAlertView *alerta = [[UIAlertView alloc] initWithTitle:@"Língua:" message:@"Selecione a língua:" delegate:self cancelButtonTitle:@"Cancelar" otherButtonTitles:@"Português",@"Inglês",@"Espanhol",@"Alemão", nil]; //create an alert for selecting the language of tesseract before taking the picture
    [alerta show]; //shows the alert
}

- (IBAction)apertouTres:(id)sender
{
    isOpenCVOn = !isOpenCVOn; //Invert OpenCV processing state
    
}

- (IBAction)handleRotation:(UIRotationGestureRecognizer *)sender {
    sender.view.transform = CGAffineTransformRotate(sender.view.transform, sender.rotation); //Rotate the UIImageView which debugs the OCR photo
    sender.rotation = 0;
}


- (IBAction)handlePan:(UIPanGestureRecognizer *)recognizer {
    if(![self.imageView isHidden]){
        CGPoint translation = [recognizer translationInView:self.imageView]; //some methods for handling touch on the OCR photo
        recognizer.view.center = CGPointMake(recognizer.view.center.x + translation.x,
                                             recognizer.view.center.y + translation.y);
        [recognizer setTranslation:CGPointMake(0, 0) inView:self.imageView];
    }
    
    if (recognizer.state == UIGestureRecognizerStateEnded) {
        
        CGPoint velocity = [recognizer velocityInView:self.view];
        CGFloat magnitude = sqrtf((velocity.x * velocity.x) + (velocity.y * velocity.y));
        CGFloat slideMult = magnitude / 200;
        NSLog(@"magnitude: %f, slideMult: %f", magnitude, slideMult);
        
        float slideFactor = 0.1 * slideMult; // Increase for more of a slide
        CGPoint finalPoint = CGPointMake(recognizer.view.center.x + (velocity.x * slideFactor),
                                         recognizer.view.center.y + (velocity.y * slideFactor));
        finalPoint.x = MIN(MAX(finalPoint.x, 0), self.view.bounds.size.width);
        finalPoint.y = MIN(MAX(finalPoint.y, 0), self.view.bounds.size.height);
        
        [UIView animateWithDuration:slideFactor*2 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            recognizer.view.center = finalPoint;
        } completion:nil];
        
    }
}

- (IBAction)handlePinch:(UIPinchGestureRecognizer *)sender {
    sender.view.transform = CGAffineTransformScale(sender.view.transform, sender.scale, sender.scale); //change the scale of UIImageView
    sender.scale = 1;
}

- (IBAction)handleTap:(UITapGestureRecognizer *)sender {
    if (sender.state == UIGestureRecognizerStateEnded) {
        [self.imageView setHidden:YES]; //dipose the UIImageView
        
    }
}

- (void)timerFireMethod:(NSTimer*)theTimer{
    isOpenCVOn=YES; //turn the OpenCV processing back on

}

- (IBAction)toqueStepperUm:(UIStepper *)sender {
    threshold = self.stepperOne.value; //add value to threshold
    NSLog(@"Threshold: %f",threshold);
    
}

- (IBAction)toqueStepperDois:(UIStepper *)sender {
    n_erode_dilate = self.stepperTwo.value; //add value to errode dialte
    NSLog(@"nerrodefdilatesrta: %d", n_erode_dilate);
}

#pragma mark - Tesseract:

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    [self.tesseract clear]; //clean the tesseract
    if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Português"]) {
        Tesseract *tesseractHolder = [[Tesseract alloc] initWithDataPath:@"tessdata" language:@"por"]; //initialize a new tesseract build with the selected language
        if(tesseractHolder) { //if it exists
            tesseract=tesseractHolder; //set the recently initialided method over the synthesized one
            NSLog(@"linguagem muda pra por");
            recognize=true; //set the flag allowing the picture to be taken
        } else
            NSLog(@"erro na troca de linguagem pra por");
    }
    else { if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Inglês"]) {
        Tesseract *tesseractHolder = [[Tesseract alloc] initWithDataPath:@"tessdata" language:@"eng"]; //same thing as before, but for english
        if(tesseractHolder) {
            tesseract=tesseractHolder;
            NSLog(@"linguagem muda pra eng");
            recognize=true;
        } else
            NSLog(@"erro na troca de linguagem pra eng");
    }
    else { if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Espanhol"]) {
        Tesseract *tesseractHolder = [[Tesseract alloc] initWithDataPath:@"tessdata" language:@"spa"]; //same thing as before, but for spanish
        if(tesseractHolder) {
            tesseract=tesseractHolder;
            NSLog(@"linguagem muda pra spa");
            recognize=true;
        } else
            NSLog(@"erro na troca de linguagem pra spa");
    }
    else { if ([[alertView buttonTitleAtIndex:buttonIndex] isEqualToString:@"Alemão"]) {
        Tesseract *tesseractHolder = [[Tesseract alloc] initWithDataPath:@"tessdata" language:@"deu"]; //same thing as before, but for german
        if(tesseractHolder) {
            tesseract=tesseractHolder;
            NSLog(@"linguagem muda pra deu");
            recognize=true;
        } else
            NSLog(@"erro na troca de linguagem pra deu");
    }}}}
}

#pragma mark - Image processing:
// this does the trick to have tesseract accept the UIImage.
-(UIImage *) gs_convert_image:(UIImage *)src_img {
    CGColorSpaceRef d_colorSpace = CGColorSpaceCreateDeviceRGB();
    /*
     * Note we specify 4 bytes per pixel here even though we ignore the
     * alpha value; you can't specify 3 bytes per-pixel.
     */
    size_t d_bytesPerRow = src_img.size.width * 4;
    unsigned char * imgData = (unsigned char*)malloc(src_img.size.height*d_bytesPerRow);
    CGContextRef context =  CGBitmapContextCreate(imgData, src_img.size.width,
                                                  src_img.size.height,
                                                  8, d_bytesPerRow,
                                                  d_colorSpace,
                                                  kCGImageAlphaNoneSkipFirst);
    
    UIGraphicsPushContext(context);
    // These next two lines 'flip' the drawing so it doesn't appear upside-down.
    CGContextTranslateCTM(context, 0.0, src_img.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    // Use UIImage's drawInRect: instead of the CGContextDrawImage function, otherwise you'll have issues when the source image is in portrait orientation.
    [src_img drawInRect:CGRectMake(0.0, 0.0, src_img.size.width, src_img.size.height)];
    UIGraphicsPopContext();
    
    /*
     * At this point, we have the raw ARGB pixel data in the imgData buffer, so
     * we can perform whatever image processing here.
     */
    
    
    // After we've processed the raw data, turn it back into a UIImage instance.
    CGImageRef new_img = CGBitmapContextCreateImage(context);
    UIImage * convertedImage = [[UIImage alloc] initWithCGImage:
                                new_img];
    
    CGImageRelease(new_img);
    CGContextRelease(context);
    CGColorSpaceRelease(d_colorSpace);
    free(imgData);
    return convertedImage;
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection
{
    //MARK: Most Important Method
    
    /*if(isTorchOn){
        NSError *__autoreleasing* errores = NULL;
        [captureDevice lockForConfiguration:errores];
        
        [captureDevice setTorchMode:AVCaptureTorchModeOn];
        
        [captureDevice unlockForConfiguration];
    } else {
        NSError *__autoreleasing* errores = NULL;
        [captureDevice lockForConfiguration:errores];
        
        [captureDevice setTorchMode:AVCaptureTorchModeOff];
        
        [captureDevice unlockForConfiguration];
     }*/ //need to add all this torch to a watchForKeyValue: method
    if(isOpenCVOn) {
        // CMSampleBufferIsValid(sampleBuffer) ? NSLog(@"sampleBuffer is valid") : NSLog(@"WARNING: sampleBuffer is invalid");
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        //OSType format = CVPixelBufferGetPixelFormatType(pixelBuffer);
        CGRect videoRect = CGRectMake(0.0f, 0.0f, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
        AVCaptureVideoOrientation videoOrientation = AVCaptureVideoOrientationPortrait;
        
        
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        //
        CIContext *temporaryContext = [CIContext contextWithOptions:nil];
        CGImageRef videoImage = [temporaryContext
                                 createCGImage:ciImage
                                 fromRect:videoRect];
        
        //UIImage *imageBebug = [UIImage imageWithCGImage:videoImage scale:1.0 orientation:UIImageOrientationRight]; //UIImage portrait when saved to camera roll
        UIImage *imageBebug = [UIImage imageWithCGImage:videoImage];
        CGImageRelease(videoImage);
        //UIImageWriteToSavedPhotosAlbum(imageBebug, nil, nil, nil);
        
        cv::Mat mat = [imageBebug CVMat];
        //UIImageWriteToSavedPhotosAlbum([UIImage imageWithCVMat:mat], nil, nil, nil);
        //NSLog(@"salvou caremera lrosal");
        
        [self processFrame:mat videoRect:videoRect videoOrientation:videoOrientation];
        
        mat.release();
    } else {
        NSArray *sublayers = [NSArray arrayWithArray:[self.recordPreview.layer sublayers]];
        for (CALayer *layer in sublayers) {
            NSString *layerName = [layer name];
            if ([layerName isEqualToString:@"FaceLayer"])
                [layer setHidden:YES];
        }
        
        
        
    }
    
    // TODO TODO TODO TODO TODO TODO TODO TODO TODO
    if(recognize){
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD showHUDAddedTo:self.view animated:YES];});
        //[tesseract setVariableValue:@"ABCDEFGHIJKLMNOPQRSTUVWXYZÇabcdefghijklmnopqrstuvwxyzçÁÉÍÓÚáéíóúÜüÔôêÊÀàõÕãÃ!@#$%¨&*()[]{}\"'" forKey:@"tessedit_char_whitelist"];
        NSLog(@"%@",[stillImage description]);
        AVCaptureConnection *vc = [stillImage connectionWithMediaType:AVMediaTypeVideo];
        [stillImage captureStillImageAsynchronouslyFromConnection:vc completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            NSLog(@"bloco de AVCaptureStillImageOutput capturestillimageassuybncaslopdfaslfgrofmcoennction");
            NSLog(@"%@",error);
            NSLog(@"%@", imageDataSampleBuffer);
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *img = [[UIImage alloc] initWithData:imageData];
            img=[self gs_convert_image:img];
            
            NSLog(@"%@", [img description]);
            // = [self imageFromSampleBuffer:sampleBuffer];
            if (img!=nil) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.imageView setImage:img];
                    [self.imageView setHidden:NO];
                    
                    [MBProgressHUD hideHUDForView:self.view animated:YES];});
                //UIImageWriteToSavedPhotosAlbum(img, nil, nil, nil); //NEEDED TO SAVE TO CAMERA ROLL
                NSLog(@"saiu uimage");
                
                
                [self.tesseract setImage:img];
                NSLog(@"começa a reconhecer");
                NSLog([self.tesseract recognize] ? @"Reconheceu" : @"não reconheceu");
                NSLog(@"terminou");
                NSLog(@"%@",[self.tesseract description]);
                NSString *textoReconhecido = [self.tesseract recognizedText];
                [self.tesseract clear];
                NSLog(@"%@", textoReconhecido);
                NSLog(@"deveria ter mostrado");
                if (UIAccessibilityIsVoiceOverRunning()) {
                    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
                                                    textoReconhecido);
                }
                UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Texto reconhecido:" message:textoReconhecido delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [message show];
            }
        }];
        recognize=false;
    }
}


#pragma mark - Implementation of FaceTracker:
- (void)processFrame:(cv::Mat &)mat videoRect:(CGRect)rect videoOrientation:(AVCaptureVideoOrientation)videOrientation
{
    // Shrink video frame to 320X240
     cv::resize(mat, mat, cv::Size(), 0.5f, 0.5f, CV_INTER_LINEAR);
    rect.size.width /= 2.0f;
    rect.size.height /= 2.0f;
    
    // Rotate video frame by 90deg to portrait by combining a transpose and a flip
    // Note that AVCaptureVideoDataOutput connection does NOT support hardware-accelerated
    // rotation and mirroring via videoOrientation and setVideoMirrored properties so we
    // need to do the rotation in software here.
    cv::transpose(mat, mat);
    CGFloat temp = rect.size.width;
    rect.size.width = rect.size.height;
    rect.size.height = temp;
    
    if (videOrientation == AVCaptureVideoOrientationLandscapeRight)
    {
        // flip around y axis for back camera
        cv::flip(mat, mat, 1);
    }
    else {
        // Front camera output needs to be mirrored to match preview layer so no flip is required here
    }
    cv::flip(mat, mat, 1);
    
    videOrientation = AVCaptureVideoOrientationPortrait;
    
    // Detect faces
    cv::Rect sheet;
    // MARK: AQUI ENTRA O OPENCV
    //UIImageWriteToSavedPhotosAlbum([UIImage imageWithCVMat:mat], nil, nil, nil);
    //_faceCascade.detectMultiScale(mat, faces, 1.1, 2, kHaarOptions, cv::Size(60, 60))
    
    
    
    //MARK: inicia a colação do metodo contron objectonview aqui
    sheet = [self contornObjectOnView:mat];
    mat.release();
    
    
    // Dispatch updating of face markers to main queue
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self displaySheet:sheet
              forVideoRect:rect
          videoOrientation:videOrientation
                 withColor:[UIColor greenColor]];
        [self displayPadrao:padrao
              forVideoRect:rect
          videoOrientation:videOrientation
                 withColor:[UIColor redColor]];
    });
}

- (cv::Rect) contornObjectOnView:(cv::Mat&)img {

    
    cv::Mat m = img.clone();
    cv::cvtColor(m, m, CV_RGB2GRAY); // Converte pra escala de cinza
    cv::blur(m, m, cv::Size(5,5));
    cv::threshold(m, m, threshold, 255,CV_THRESH_BINARY);
    cv::erode(m, m, cv::Mat(),cv::Point(-1,-1),n_erode_dilate);
    cv::dilate(m, m, cv::Mat(),cv::Point(-1,-1),n_erode_dilate);
    
    std::vector< std::vector<cv::Point> > contours;
    std::vector<cv::Point> points;
    cv::findContours(m, contours, CV_RETR_LIST, CV_CHAIN_APPROX_NONE);
    for (size_t i=0; i<contours.size(); i++) {
        for (size_t j = 0; j < contours[i].size(); j++) {
            cv::Point p = contours[i][j];
            points.push_back(p);
        }
    }
    // Aqui da pra escolher se quer retornar ou pode contornar aqui mesmo
    
    // Se for desenhar o retângulo aqui mesmo:
    //Senão é só substituir isso por "cv::Rect brect = cv::boundingRect(cv::Mat(points).reshape(2));
    return cv::boundingRect(cv::Mat(points).reshape(2));
    /*if(points.size() > 0){
     cv::Rect brect = cv::boundingRect(cv::Mat(points).reshape(2));
     cv::rectangle(img, brect.tl(), brect.br(), cv::Scalar(100, 100, 200), 2, CV_AA);*/
}


// Update face markers given vector of face rectangles
- (void)displaySheet:(const cv::Rect &)squares
        forVideoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videoOrientation
           withColor:(UIColor*) color
{
    NSArray *sublayers = [NSArray arrayWithArray:[self.recordPreview.layer sublayers]];
    int sublayersCount = [sublayers count];
    int currentSublayer = 0;
    
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	
	// hide all the face layers
	for (CALayer *layer in sublayers) {
        NSString *layerName = [layer name];
		if ([layerName isEqualToString:@"FaceLayer"])
			[layer setHidden:YES];
	}
    
    // Create transform to convert from vide frame coordinate space to view coordinate space
    CGAffineTransform t = [self affineTransformForVideoFrame:rect orientation:videoOrientation];
    
        CGRect faceRect;
        faceRect.origin.x = squares.x;
        faceRect.origin.y = squares.y;
        faceRect.size.width = squares.width;
        faceRect.size.height = squares.height;
        NSLog(@"x: %d y: %d width: %d  height: %d", squares.x, squares.y, squares.width, squares.height);
    
     faceRect = CGRectApplyAffineTransform(faceRect, t);
        
        CALayer *featureLayer = nil;
        
        while (!featureLayer && (currentSublayer < sublayersCount)) {
			CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
			if ([[currentLayer name] isEqualToString:@"FaceLayer"]) {
				featureLayer = currentLayer;
				[currentLayer setHidden:NO];
			}
		}
        
        if (!featureLayer) {
            // Create a new feature marker layer
			featureLayer = [[CALayer alloc] init];
            featureLayer.name = @"FaceLayer";
            featureLayer.borderColor = [color CGColor];
            featureLayer.borderWidth = 1.0f;
			[self.recordPreview.layer addSublayer:featureLayer];
		}
        
        featureLayer.frame = faceRect;
    
    [CATransaction commit];
}

- (void)displayPadrao:(const cv::Rect &)squares
        forVideoRect:(CGRect)rect
    videoOrientation:(AVCaptureVideoOrientation)videoOrientation
           withColor:(UIColor*) color
{
    NSArray *sublayers = [NSArray arrayWithArray:[self.recordPreview.layer sublayers]];
    int sublayersCount = [sublayers count];
    int currentSublayer = 0;
    
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	
	// hide all the face layers
	for (CALayer *layer in sublayers) {
        NSString *layerName = [layer name];
		if ([layerName isEqualToString:@"FaceLayer2"])
			[layer setHidden:YES];
	}
    
    // Create transform to convert from vide frame coordinate space to view coordinate space
    CGAffineTransform t = [self affineTransformForVideoFrame:rect orientation:videoOrientation];
    
    CGRect faceRect;
    faceRect.origin.x = squares.x;
    faceRect.origin.y = squares.y;
    faceRect.size.width = squares.width;
    faceRect.size.height = squares.height;
    NSLog(@"x: %d y: %d width: %d  height: %d", squares.x, squares.y, squares.width, squares.height);
    
    faceRect = CGRectApplyAffineTransform(faceRect, t);
    
    CALayer *featureLayer = nil;
    
    while (!featureLayer && (currentSublayer < sublayersCount)) {
        CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
        if ([[currentLayer name] isEqualToString:@"FaceLayer2"]) {
            featureLayer = currentLayer;
            [currentLayer setHidden:NO];
        }
    }
    
    if (!featureLayer) {
        // Create a new feature marker layer
        featureLayer = [[CALayer alloc] init];
        featureLayer.name = @"FaceLayer2";
        featureLayer.borderColor = [color CGColor];
        featureLayer.borderWidth = 1.0f;
        [self.recordPreview.layer addSublayer:featureLayer];
    }
    
    featureLayer.frame = faceRect;
    
    [CATransaction commit];
}


#pragma mark - Camera initialization:

- (CGAffineTransform)affineTransformForVideoFrame:(CGRect)videoFrame orientation:(AVCaptureVideoOrientation)videoOrientation
{
    CGSize viewSize = self.recordPreview.bounds.size;
    NSString * const videoGravity = captureLayer.videoGravity;
    CGFloat widthScale = 1.0f;
    CGFloat heightScale = 1.0f;
    
    // Move origin to center so rotation and scale are applied correctly
    CGAffineTransform t = CGAffineTransformMakeTranslation(-videoFrame.size.width / 2.0f, -videoFrame.size.height / 2.0f);
    
    switch (videoOrientation) {
        case AVCaptureVideoOrientationPortrait:
            widthScale = viewSize.width / videoFrame.size.width;
            heightScale = viewSize.height / videoFrame.size.height;
            break;
            
        case AVCaptureVideoOrientationPortraitUpsideDown:
            t = CGAffineTransformConcat(t, CGAffineTransformMakeRotation(M_PI));
            widthScale = viewSize.width / videoFrame.size.width;
            heightScale = viewSize.height / videoFrame.size.height;
            break;
            
        case AVCaptureVideoOrientationLandscapeRight:
            t = CGAffineTransformConcat(t, CGAffineTransformMakeRotation(M_PI_2));
            widthScale = viewSize.width / videoFrame.size.height;
            heightScale = viewSize.height / videoFrame.size.width;
            break;
            
        case AVCaptureVideoOrientationLandscapeLeft:
            t = CGAffineTransformConcat(t, CGAffineTransformMakeRotation(-M_PI_2));
            widthScale = viewSize.width / videoFrame.size.height;
            heightScale = viewSize.height / videoFrame.size.width;
            break;
    }
    
    // Adjust scaling to match video gravity mode of video preview
    if (videoGravity == AVLayerVideoGravityResizeAspect) {
        heightScale = MIN(heightScale, widthScale);
        widthScale = heightScale;
    }
    else if (videoGravity == AVLayerVideoGravityResizeAspectFill) {
        heightScale = MAX(heightScale, widthScale);
        widthScale = heightScale;
    }
    
    // Apply the scaling
    t = CGAffineTransformConcat(t, CGAffineTransformMakeScale(widthScale, heightScale));
    
    // Move origin back from center
    t = CGAffineTransformConcat(t, CGAffineTransformMakeTranslation(viewSize.width / 2.0f, viewSize.height / 2.0f));
    
    return t;
}

- (BOOL)createCaptureSessionForCamera:(NSInteger)camera qualityPreset:(NSString *)qualityPreset grayscale:(BOOL)grayscale
{
    
	
    // Set up AV capture
    NSArray* devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    if ([devices count] == 0) {
        NSLog(@"No video capture devices found");
        return NO;
    }
    
    if (self.camera == -1) {
        self.camera = -1;
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    else if (self.camera >= 0 && self.camera < [devices count]) {
        captureDevice = [devices objectAtIndex:self.camera] ;
    }
    else {
        self.camera = -1;
        captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        NSLog(@"Camera number out of range. Using default camera");
    }
    NSError *__autoreleasing* errores = NULL;
    [captureDevice lockForConfiguration:errores];
    
    [captureDevice setTorchMode:AVCaptureTorchModeOff];

    [captureDevice unlockForConfiguration];
    // Create the capture session
    captureSession = [[AVCaptureSession alloc] init];
    captureSession.sessionPreset = (self.qualityPreset)? self.qualityPreset : AVCaptureSessionPresetHigh;
    
    // Create device input
    NSError *error = nil;
    AVCaptureDeviceInput *input = [[AVCaptureDeviceInput alloc] initWithDevice:captureDevice error:&error];
    
    // Create and configure device output
    videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    
    dispatch_queue_t queue = dispatch_queue_create("cameraQueue", NULL);
    [videoOutput setSampleBufferDelegate:self queue:queue];
    
    videoOutput.alwaysDiscardsLateVideoFrames = YES;
    // captureDevice.activeVideoMinFrameDuration = CMTimeMake(1, 30);
    
    
    // For grayscale mode, the luminance channel from the YUV fromat is used
    // For color mode, BGRA format is used
    OSType format = kCVPixelFormatType_32BGRA;
    
    // Check YUV format is available before selecting it (iPhone 3 does not support it)
    if (grayscale && [videoOutput.availableVideoCVPixelFormatTypes containsObject:
                      [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]]) {
        format = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    }
    
    videoOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:format]
                                                            forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    
    // Connect up inputs and outputs
    if ([captureSession canAddInput:input]) {
        [captureSession addInput:input];
    }
    
    if ([captureSession canAddOutput:videoOutput]) {
        [captureSession addOutput:videoOutput];
    }
    
    stillImage = [[AVCaptureStillImageOutput alloc] init];
    stillImage.outputSettings = [NSDictionary dictionaryWithObject:AVVideoCodecJPEG
                                                            forKey:AVVideoCodecKey];
    
    NSLog(@"canAddOutput: stillImage: %hhd",[captureSession canAddOutput:stillImage]);
    if ([captureSession canAddOutput:stillImage]){
        [captureSession addOutput:stillImage];
    }
    
    // Create the preview layer
    captureLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:captureSession];
    [captureLayer setFrame:self.recordPreview.bounds];
    captureLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.recordPreview.layer insertSublayer:captureLayer atIndex:0];
    
    self.tesseract = [[Tesseract alloc] initWithDataPath:@"tessdata" language:@"por"];
    
    return YES;
}


@end
