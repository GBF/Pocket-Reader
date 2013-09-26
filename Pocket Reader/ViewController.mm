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
#import "text_detect.h"

@interface ViewController () {
    cv::Rect padrao;
    
    std::vector<cv::Vec4i> lines;
}
@end

@implementation ViewController

@synthesize camera;
@synthesize captureGrayscale;
@synthesize captureSession;
@synthesize qualityPreset;
@synthesize captureDevice;
@synthesize captureLayer;
@synthesize videoOutput;
@synthesize stillImage;
@synthesize tesseract;
@synthesize dataClass;


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
    [self timerFireMethod:nil]; // prints a red rectangle on the screen for DEBUG
    [self setTorch:NO]; //turn flash off
    dataClass = [PocketReaderDataClass getInstance];
    dataClass.isOpenCVOn = YES;
    dataClass.binarizeSelector=0;
    dataClass.sheetErrorRange = 10;
    dataClass.tesseractLanguage = @"por";
    dataClass.threshold = 150;
    n_erode_dilate = 1;
    self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    //[self.recordPreview setBounds:]
    dataClass.openCVMethodSelector = 1;
    if (!UIAccessibilityIsVoiceOverRunning()) {
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"VoiceOver inactive" message:@"Warning: VoiceOver is currently off. Pocket Reader is meant to be used with VoiceOver feature turned on." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [message show];
    }
    
    [self createCaptureSessionForCamera:camera qualityPreset:qualityPreset grayscale:captureGrayscale]; //set camera and it view
    [captureSession startRunning]; //start the camera capturing
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    dataClass.isOpenCVOn = NO; //disable OpenCV processing and let ARC clean the memory
    [self performSelector:@selector(timerFireMethod:) withObject:nil afterDelay:2.0]; //after 2 seconds turn openCV on again
    
    // Dispose of any resources that can be recreated.
    
}

#pragma mark - Buttons:

- (IBAction)apertouUm:(id)sender
{
    [self setTorch:![captureDevice isTorchActive]]; //Invert the flash state
}

#pragma mark - Tesseract:

- (IBAction)apertouDois:(id)sender
{
    [self.tesseract clear]; //clean the tesseract
    self.tesseract=nil;
    Tesseract *tesseractHolder = [[Tesseract alloc] initWithDataPath:@"tessdata" language:dataClass.tesseractLanguage];
            self.tesseract=tesseractHolder;
    NSLog(@"Mudou pra %@",dataClass.tesseractLanguage);
    while([captureDevice isAdjustingFocus]);
    recognize=YES;
}

- (void) setTorch:(BOOL)torchState {
    if ([captureDevice hasTorch]){
        if(torchState){
            NSError *__autoreleasing* errores = NULL;
            [captureDevice lockForConfiguration:errores];
            [captureDevice setTorchMode:AVCaptureTorchModeOn];
            
            [captureDevice unlockForConfiguration];
        } else {
            NSError *__autoreleasing* errores = NULL;
            [captureDevice lockForConfiguration:errores];
            [captureDevice setTorchMode:AVCaptureTorchModeOff];
            
            [captureDevice unlockForConfiguration];
        }
    }
    
}

- (void)timerFireMethod:(NSTimer*)theTimer {
    dataClass.isOpenCVOn = YES;
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
    
    if(dataClass.isOpenCVOn) {
        
        if(dataClass.openCVMethodSelector==0){NSArray *sublayers = [NSArray arrayWithArray:[self.recordPreview.layer sublayers]];
        int sublayersCount = [sublayers count];
        int currentSublayer = 0;
        
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        
        // hide all the face layers
        for (CALayer *layer in sublayers) {
            NSString *layerName = [layer name];
            if ([layerName isEqualToString:@"DefaultLayer"])
                [layer setHidden:YES];
        }
        
        // Create transform to convert from vide frame coordinate space to view coordinate space
        CGAffineTransform t = [self affineTransformForVideoFrame:self.recordPreview.bounds orientation:AVCaptureVideoOrientationPortrait];
        
        CGRect faceRect = CGRectMake(padrao.x/1.0f, padrao.y/1.0f, padrao.width/1.0f, padrao.height/1.0f);
        
        faceRect = CGRectApplyAffineTransform(faceRect, t);
        
        CALayer *featureLayer = nil;
        
        while (!featureLayer && (currentSublayer < sublayersCount)) {
            CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
            if ([[currentLayer name] isEqualToString:@"DefaultLayer"]) {
                featureLayer = currentLayer;
                [currentLayer setHidden:NO];
            }
        }
        
        if (!featureLayer) {
            // Create a new feature marker layer
            featureLayer = [[CALayer alloc] init];
            featureLayer.name = @"DefaultLayer";
            featureLayer.borderColor = [[UIColor redColor] CGColor];
            featureLayer.borderWidth = 1.0f;
            [self.recordPreview.layer addSublayer:featureLayer];
        }
        
        
        
        featureLayer.frame = faceRect;
        
        [CATransaction commit];
        }
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        CGRect videoRect = CGRectMake(0.0f, 0.0f, CVPixelBufferGetWidth(pixelBuffer), CVPixelBufferGetHeight(pixelBuffer));
        AVCaptureVideoOrientation videoOrientation = AVCaptureVideoOrientationPortrait;
        
        
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        CIContext *temporaryContext = [CIContext contextWithOptions:nil];
        CGImageRef videoImage = [temporaryContext
                                 createCGImage:ciImage
                                 fromRect:videoRect];
        
        UIImage *imageBebug = [UIImage imageWithCGImage:videoImage];
        CGImageRelease(videoImage);
        
        if(dataClass.openCVMethodSelector==0 || dataClass.openCVMethodSelector==1){
            
        cv::Mat mat = [imageBebug CVMat];
        
        
        [self processFrame:mat videoRect:videoRect videoOrientation:videoOrientation];
        
            mat.release();
        } else if (dataClass.openCVMethodSelector==2){
            //if  there's a third method
        }
        
    } else {
        NSArray *sublayers = [NSArray arrayWithArray:[self.recordPreview.layer sublayers]];
        for (CALayer *layer in sublayers) {
            if ([[layer name] isEqualToString:@"DefaultLayer"])
                [layer setHidden:YES];
            if ([[layer name] isEqualToString:@"SheetLayer"])
                [layer setHidden:YES];
        }
        
        
        
    }
    
    if(recognize){
        BOOL torchPreviousState = [captureDevice isTorchActive];
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD showHUDAddedTo:self.view animated:YES];});
        NSLog(@"%@",[stillImage description]);
        AVCaptureConnection *vc = [stillImage connectionWithMediaType:AVMediaTypeVideo];
        [stillImage captureStillImageAsynchronouslyFromConnection:vc completionHandler:^(CMSampleBufferRef imageDataSampleBuffer, NSError *error) {
            [self setTorch:NO];
            NSLog(@"bloco de AVCaptureStillImageOutput capturestillimageassuybncaslopdfaslfgrofmcoennction");
            NSLog(@"%@",error);
            NSLog(@"%@", imageDataSampleBuffer);
            NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
            UIImage *img = [[UIImage alloc] initWithData:imageData];
            img=[self gs_convert_image:img];
            
            NSLog(@"%@", [img description]);
            if (img!=nil) {
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
                dispatch_async(dispatch_get_main_queue(), ^{
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                });
                if (UIAccessibilityIsVoiceOverRunning()) {
                    UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
                                                    textoReconhecido);
                }
                UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Texto reconhecido:" message:textoReconhecido delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
                [message show];
                [self setTorch:torchPreviousState];
            }
        }];
        recognize=false;
    }
}

-(void) recognizeText:(UIImage*)img {
    dispatch_async(dispatch_get_main_queue(), ^{
        [MBProgressHUD showHUDAddedTo:self.view animated:YES];});
    img=[self gs_convert_image:img];
    
    if (img!=nil) {

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
        dispatch_async(dispatch_get_main_queue(), ^{
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        });
        if (UIAccessibilityIsVoiceOverRunning()) {
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification,
                                            textoReconhecido);
        }
        UIAlertView *message = [[UIAlertView alloc] initWithTitle:@"Texto reconhecido:" message:textoReconhecido delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [message show];
    }

}

-(void) viewWillAppear:(BOOL)animated {
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
}

-(void) viewWillDisappear:(BOOL)animated {
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void) usePicker {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    [picker setDelegate:self];
    [picker setAllowsEditing:YES];
    [picker setSourceType:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
    
    [self presentViewController:picker animated:YES completion:nil];
}

-(void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    // Dismiss the picker
    dispatch_async(dispatch_get_main_queue(), ^{
        [self dismissViewControllerAnimated:YES completion:nil];
    });
    
    // Get the image from the result
    [self recognizeText:[info valueForKey:@"UIImagePickerControllerOriginalImage"]];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissViewControllerAnimated:YES completion:nil];
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
    
    
    // Detect faces
    cv::Rect sheet;
    // MARK: Here comes the OpenCV methods
    if (dataClass.openCVMethodSelector == 0) {
        sheet = [self contornObjectOnView:mat];
    mat.release();
    
    if (
        //     (padrao.x - dataClass.sheetErrorRange) < sheet.x < (padrao.x + dataClass.sheetErrorRange) && (padrao.y - dataClass.sheetErrorRange) < sheet.y < (padrao.y + dataClass.sheetErrorRange) && (padrao.width - dataClass.sheetErrorRange) < sheet.width < (padrao.width + dataClass.sheetErrorRange) && (padrao.height - dataClass.sheetErrorRange) < sheet.height < (padrao.height + dataClass.sheetErrorRange)
        sheet==padrao
        )
    {
        while([captureDevice isAdjustingFocus]);
        recognize=YES;
        // TODO: Depois de detectar a folha cortar ela da foto
        // TODO: pegar a imagem do rolo da câmera
        // TODO: salvar em um arquivo os textos
    }
    
    // Dispatch updating of face markers to main queue
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self displaySheet:sheet
              forVideoRect:rect
          videoOrientation:AVCaptureVideoOrientationPortrait
                 withColor:[UIColor greenColor]];
        [self.imageView setHidden:YES];
    });
        
    }
    else if (dataClass.openCVMethodSelector == 1) {
        dispatch_sync(dispatch_get_main_queue(),^{
            NSArray *sublayers = [NSArray arrayWithArray:[self.recordPreview.layer sublayers]];
        for (CALayer *layer in sublayers) {
            if ([[layer name] isEqualToString:@"DefaultLayer"])
                [layer setHidden:YES];
            if ([[layer name] isEqualToString:@"SheetLayer"])
                [layer setHidden:YES];
        }
            [self.imageView setHidden:NO];});
        [self findAndDrawSheet:mat];
        mat.release();
    }
}

- (cv::Rect) contornObjectOnView:(cv::Mat&)img {
    
    cv::Mat m = img.clone();
    cv::cvtColor(m, m, CV_RGB2GRAY);
    cv::blur(m, m, cv::Size(5,5));
    cv::threshold(m, m, dataClass.threshold, 255,dataClass.binarizeSelector | CV_THRESH_OTSU);
    cv::erode(m, m, cv::Mat(),cv::Point(-1,-1),n_erode_dilate);
    cv::dilate(m, m, cv::Mat(),cv::Point(-1,-1),n_erode_dilate);
    
    std::vector< std::vector<cv::Point> > contours;
    std::vector<cv::Point> points;
    cv::findContours(m, contours, CV_RETR_LIST, CV_CHAIN_APPROX_NONE);
    m.release();
    for (size_t i=0; i<contours.size(); i++) {
        for (size_t j = 0; j < contours[i].size(); j++) {
            cv::Point p = contours[i][j];
            points.push_back(p);
        }
    }
    return cv::boundingRect(cv::Mat(points).reshape(2));
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
		if ([layerName isEqualToString:@"SheetLayer"])
			[layer setHidden:YES];
	}
    
    // Create transform to convert from vide frame coordinate space to view coordinate space
    CGAffineTransform t = [self affineTransformForVideoFrame:rect orientation:videoOrientation];
    
    CGRect faceRect;
    faceRect.origin.x = squares.x;
    faceRect.origin.y = squares.y;
    faceRect.size.width = squares.width;
    faceRect.size.height = squares.height;
    
    faceRect = CGRectApplyAffineTransform(faceRect, t);
    
    CALayer *featureLayer = nil;
    
    while (!featureLayer && (currentSublayer < sublayersCount)) {
        CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
        if ([[currentLayer name] isEqualToString:@"SheetLayer"]) {
            featureLayer = currentLayer;
            [currentLayer setHidden:NO];
        }
    }
    
    if (!featureLayer) {
        // Create a new feature marker layer
        featureLayer = [[CALayer alloc] init];
        featureLayer.name = @"SheetLayer";
        featureLayer.borderColor = [color CGColor];
        featureLayer.borderWidth = 1.0f;
        [self.recordPreview.layer addSublayer:featureLayer];
    }
    
    featureLayer.frame = faceRect;
    
    if(!dataClass.isOpenCVOn){
        for (CALayer *layer in sublayers) {
            NSString *layerName = [layer name];
            if ([layerName isEqualToString:@"SheetLayer"])
                [layer setHidden:YES];
        }
    }
    
    [CATransaction commit];
    
   
}


#pragma mark - Hough Transform Implementation
-(void) findAndDrawSheet: (cv::Mat &)image {

    
/*    UIGraphicsBeginImageContext(self.recordPreview.frame.size);
    CGContextRef context = UIGraphicsGetCurrentContext(); //erro de agora: não tem cotexto nenhum, tá desenhando no nada, tem que delgar uma CALayer do recordpreview. (como? no sei)
    CGContextSetStrokeColorWithColor(context, [UIColor greenColor].CGColor);
    CGContextSetLineWidth(context, 2.0);*/
    self.imageView.image =nil;
    cv::cvtColor(image, image, CV_RGB2GRAY);
    cv::Canny(image, image, 50, 250, 3);
    lines.clear();
    cv::HoughLinesP(image, lines, 1, CV_PI/180, dataClass.threshold, 50, 10);
    std::vector<cv::Vec4i>::iterator it = lines.begin();
    for(; it!=lines.end(); ++it) {
        cv::Vec4i l = *it;
        //NSLog(@"inicio x: %d, y: %d, fim x: %d, y: %d",l[0],l[1],l[2],l[3]);
        
        cv::line(image, cv::Point(l[0], l[1]), cv::Point(l[2], l[3]), cv::Scalar(255,0,0), 2, CV_AA); //<----- usa essa função e cria uma cv::Mat com fundo transparente, bota uma UIImageView em cima da recordPreview e fica jogando essa cv::Mat lá, tomara qiue fique transparente
    }
    cv::erode(image, image, cv::Mat(),cv::Point(-1,-1),0.5);
    cv::dilate(image, image, cv::Mat(),cv::Point(-1,-1),0.5);//remove smaller part of image

    
    
    
    
    
    //image.inv();
    image = 255- image;
    
    
    NSData *data = [NSData dataWithBytes:image.data length:image.elemSize() * image.total()];
    
    CGColorSpaceRef colorSpace;
    
    if (image.elemSize() == 1) {
        colorSpace = CGColorSpaceCreateDeviceGray();
    } else {
        colorSpace = CGColorSpaceCreateDeviceRGB();
    }
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData((__bridge CFDataRef)data);
    
    CGImageRef imageRef = CGImageCreate(image.cols,                                     // Width
                                        image.rows,                                     // Height
                                        8,                                              // Bits per component
                                        8 * image.elemSize(),                           // Bits per pixel
                                        image.step[0],                                  // Bytes per row
                                        colorSpace,                                     // Colorspace
                                        kCGImageAlphaNone | kCGBitmapByteOrderDefault,  // Bitmap info flags
                                        provider,                                       // CGDataProviderRef
                                        NULL,                                           // Decode
                                        false,                                          // Should interpolate
                                        kCGRenderingIntentDefault);
    image.release();
    const float whiteMask[6] = { 255,255,255, 255,255,255 };
    CGImageRef myColorMaskedImage = CGImageCreateWithMaskingColors(imageRef, whiteMask);
    CGImageRelease(imageRef);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.imageView setImage:[UIImage imageWithCGImage:myColorMaskedImage]];
        CGImageRelease(myColorMaskedImage); });
    
    // dataClass.isOpenCVOn = NO;
    
    /*
    
    CALayer *sheetLinesLayer = nil;
    int currentSublayer = 0;
    NSArray *sublayers = [NSArray arrayWithArray:[self.recordPreview.layer sublayers]];
    while (!sheetLinesLayer && (currentSublayer < [sublayers count])) {
        CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
        if ([[currentLayer name] isEqualToString:@"sheetLinesLayer"]) {
            sheetLinesLayer = nil;
        }
    }
    
    if(!sheetLinesLayer){
        sheetLinesLayer = [CALayer new];
        sheetLinesLayer.name = @"sheetLinesLayer";
        sheetLinesLayer.frame = self.recordPreview.frame;
        [self.recordPreview.layer addSublayer:sheetLinesLayer];
        sheetLinesLayer.delegate = self;
    }
    
    */
    return ;

}

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)ctx {
    // Check that the layer argument is yourLayer (if you are the
    // delegate to more than one layer)
    if ([[layer name] isEqualToString:@"sheetLinesLayer"]){
        
        CGContextRef context = UIGraphicsGetCurrentContext(); //erro de agora: não tem cotexto nenhum, tá desenhando no nada, tem que delgar uma CALayer do recordpreview. (como? no sei)
        CGContextSetStrokeColorWithColor(context, [UIColor greenColor].CGColor);
        CGContextSetLineWidth(context, 2.0);

        
        std::vector<cv::Vec4i>::iterator it = lines.begin();
        for(; it!=lines.end(); ++it) {
            cv::Vec4i l = *it;
            NSLog(@"inicio x: %d, y: %d, fim x: %d, y: %d",l[0],l[1],l[2],l[3]);
            CGContextMoveToPoint(context, l[0]/1.0f, l[1]/1.0f);
            CGContextAddLineToPoint(context, l[2]/1.0f, l[3]/1.0f);
            //cv::line(work_img, cv::Point(l[0], l[1]), cv::Point(l[2], l[3]), cv::Scalar(255,0,0), 2, CV_AA);
        }
        CGContextStrokePath(context);

    }
    
    // Use the context (second) argument to draw.
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
    if ([captureDevice hasTorch])
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
