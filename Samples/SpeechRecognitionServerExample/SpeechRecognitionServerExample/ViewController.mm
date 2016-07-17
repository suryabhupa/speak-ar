/*
 TODO List:
 endMicAndRecognition for ending with the button.
 Ich liebe dich repeats itself!
 Add target language configuration.
 */

/*
 * Copyright (c) Microsoft. All rights reserved.
 * Licensed under the MIT license.
 *
 * Microsoft Cognitive Services (formerly Project Oxford): https://www.microsoft.com/cognitive-services
 *
 * Microsoft Cognitive Services (formerly Project Oxford) GitHub:
 * https://github.com/Microsoft/Cognitive-Speech-STT-iOS
 *
 * Copyright (c) Microsoft Corporation
 * All rights reserved.
 *
 * MIT License:
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED ""AS IS"", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 * OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
 * WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

// azure secret: BFeZ3iSw4xd5nrE+dXWpWqwfa7dw4ipV+wlNNCJUSUI=

#import "FGTranslator.h"
#import "AFNetworking.h"

#include "precomp.h"

#import "ViewController.h"
#import <CoreImage/CoreImage.h>
#import <ImageIO/ImageIO.h>
#import <AssertMacros.h>
#import <AssetsLibrary/AssetsLibrary.h>

static CGFloat DegreesToRadians(CGFloat degrees) {return degrees * M_PI / 180;};

@interface ViewController (/*private*/)

@property (nonatomic, readonly)  NSString*               subscriptionKey;
@property (nonatomic, readonly)  NSString*               luisAppId;
@property (nonatomic, readonly)  NSString*               luisSubscriptionID;
@property (nonatomic, readonly)  bool                    useMicrophone;
@property (nonatomic, readonly)  bool                    wantIntent;
@property (nonatomic, readonly)  SpeechRecognitionMode   mode;
@property (nonatomic, readonly)  NSString*               defaultLocale;
@property (nonatomic, readonly)  NSString*               shortWaveFile;
@property (nonatomic, readonly)  NSString*               longWaveFile;
@property (nonatomic, readonly)  NSDictionary*           settings;
@property (nonatomic, readwrite) NSArray*                buttonGroup;
@property (nonatomic, readonly)  NSUInteger              modeIndex;


@property (nonatomic) BOOL isUsingFrontFacingCamera;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic) dispatch_queue_t videoDataOutputQueue;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@property (nonatomic, strong) UIImage *borderImage;
@property (nonatomic, strong) CIDetector *faceDetector;


- (void)setupAVCapture;
- (void)teardownAVCapture;
- (void)drawFaces:(NSArray *)features
      forVideoBox:(CGRect)videoBox
      orientation:(UIDeviceOrientation)orientation;


@end

NSString* ConvertSpeechRecoConfidenceEnumToString(Confidence confidence);
NSString* ConvertSpeechErrorToString(int errorCode);


/**
 * The Main App ViewController
 */
@implementation ViewController

@synthesize buttonGroup;
@synthesize micRadioButton;
@synthesize micDictationRadioButton;
@synthesize micIntentRadioButton;
@synthesize dataShortRadioButton;
@synthesize dataLongRadioButton;
@synthesize dataShortIntentRadioButton;

/**
 * Gets or sets subscription key
 */
-(NSString*)subscriptionKey {
    return [self.settings objectForKey:(@"primaryKey")];
}

/**
 * Gets the LUIS application identifier.
 * @return The LUIS application identifier.
 */
-(NSString*)luisAppId {
    return [self.settings objectForKey:(@"luisAppID")];
}

/**
 * Gets the LUIS subscription identifier.
 * @return The LUIS subscription identifier.
 */
-(NSString*)luisSubscriptionID {
    return [self.settings objectForKey:(@"luisSubscriptionID")];
}

/**
 * Gets a value indicating whether or not to use the microphone.
 * @return true if [use microphone]; otherwise, false.
 */
-(bool)useMicrophone {
    auto index = self.modeIndex;
    return index < 3;
}

/**
 * Gets a value indicating whether LUIS results are desired.
 * @return true if LUIS results are to be returned otherwise, false.
 */
-(bool)wantIntent {
    auto index = self.modeIndex;
    return index == 2 || index == 5;
}

/**
 * Gets the current speech recognition mode.
 * @return The speech recognition mode.
 */
-(SpeechRecognitionMode)mode {
    auto index = self.modeIndex;
    if (index == 1 || index == 4) {
        return SpeechRecognitionMode_LongDictation;
    }

    return SpeechRecognitionMode_ShortPhrase;
}

/**
 * Gets the default locale.
 * @return The default locale.
 */
-(NSString*)defaultLocale {
    
    return languageCode;
}

/**
 * Gets the short wave file path.
 * @return The short wave file.
 */
-(NSString*)shortWaveFile {
    return @"whatstheweatherlike";
}

/**
 * Gets the long wave file path.
 * @return The long wave file.
 */
-(NSString*)longWaveFile {
    return @"batman";
}

/**
 * Gets the current bundle settings.
 * @return The settings dictionary.
 */
-(NSDictionary*)settings {
    NSString* path = [[NSBundle mainBundle] pathForResource:@"settings" ofType:@"plist"];
    NSDictionary* settings = [[NSDictionary alloc] initWithContentsOfFile:path];
    return settings;
}

/**
 * Gets the current zero-based mode index.
 * @return The current mode index.
 */
-(NSUInteger)modeIndex {
    for(NSUInteger i = 0; i < self.buttonGroup.count; ++i) {
        UNIVERSAL_BUTTON* buttonSel = (UNIVERSAL_BUTTON*)self.buttonGroup[i];
        if (UNIVERSAL_BUTTON_GETCHECKED(buttonSel)) {
            return i;
        }
    }

    return 0;
}


/**
 * Initialization to be done when app starts.
 */

BOOL isTranslating = false;
NSString *languageTitle = @"English";
NSMutableString *languageCode = [NSMutableString stringWithString:@"en-US"];
NSMutableString *translation = [NSMutableString stringWithString: @""];

-(void)viewDidLoad {
    [super viewDidLoad];
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    
    [self setupAVCapture];
    self.borderImage = [UIImage imageNamed:@"bubble-final"];
    NSDictionary *detectorOptions = [[NSDictionary alloc] initWithObjectsAndKeys:CIDetectorAccuracyLow, CIDetectorAccuracy, nil];
    self.faceDetector = [CIDetector detectorOfType:CIDetectorTypeFace context:nil options:detectorOptions];
    
    
    ////////////////////////////////////////
    

    self.buttonGroup = [[NSArray alloc] initWithObjects:micRadioButton, 
                                                        micDictationRadioButton, 
                                                        micIntentRadioButton, 
                                                        dataShortRadioButton, 
                                                        dataLongRadioButton, 
                                                        dataShortIntentRadioButton, 
                                                        nil];
    
    // The logic for handling the language selection
    
    self.tableView.hidden = YES;
    [self.btnOutlet setBackgroundColor:[UIColor orangeColor]];
    [self.btnOutlet setTitle:languageTitle forState:UIControlStateNormal];
    //adding action programatically
    [self.btnOutlet addTarget:self action:@selector(btnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnOutlet];
    
    self.data = [[NSArray alloc]initWithObjects:@"English",@"Arabic",@"Chinese",@"Danish",@"French",@"German",@"Italian",@"Russian", nil];
    
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    
    [self showMenu:TRUE];
    textOnScreen = [NSMutableString stringWithCapacity: 1000];

    ////////
    
//    [translator supportedLanguages:^(NSError *error, NSArray *languageCodes)
//     {
//         NSLog(@"supported languages:");
//         if (error)
//             NSLog(@"failed with error: %@", error);
//         else
//             NSLog(@"supported languages:%@", languageCodes);
//     }];
    
}

- (IBAction)btnClicked:(id)sender
{
    self.tableView.hidden = !self.tableView.hidden;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    
    return [self.data count];
    
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    
    static NSString *simpleTableIdentifier = @"SimpleTableItem";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    
    
    if (cell == nil) {
        
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
        
    }
    
    
    cell.textLabel.text = [self.data objectAtIndex:indexPath.row] ;
    
    //cell.textLabel.font = [UIFont systemFontOfSize:11.0];
    
    
    return cell;
    
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
    
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
    languageTitle = cell.textLabel.text;
    [self setLanguage];
    [self.btnOutlet setTitle:cell.textLabel.text forState:UIControlStateNormal];
//    NSLog(cell.textLabel.text);
    self.tableView.hidden = YES;
    
    
}

//- (void)btn:(UI *)btn did:(NSIndexPath *)indexPath{
//    
//    
//    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
//    [self.btnOutlet setTitle:cell.textLabel.text forState:UIControlStateNormal];
//    NSLog(cell.textLabel.text);
//    self.tableView.hidden = YES;
//    
//}


- (IBAction)btnAction:(id)sender {
    
    if (self.tableView.hidden == YES) {
        self.tableView.hidden = NO;
    }
    
    else
        self.tableView.hidden = YES;
}

- (void)setLanguage {
    
    if ([languageTitle isEqualToString:@"English"]) {
        languageCode = [NSMutableString stringWithString:@"en-US"];
    } else if ([languageTitle isEqualToString:@"Arabic"]) {
        languageCode = [NSMutableString stringWithString:@"ar-EG"];
    } else if ([languageTitle isEqualToString:@"Chinese"]) {
        languageCode = [NSMutableString stringWithString:@"zh-CN"];
    } else if ([languageTitle isEqualToString:@"Danish"]) {
        languageCode = [NSMutableString stringWithString:@"da-DK"];
    } else if ([languageTitle isEqualToString:@"French"]) {
        languageCode = [NSMutableString stringWithString:@"fr-FR"];
    } else if ([languageTitle isEqualToString:@"German"]) {
        languageCode = [NSMutableString stringWithString:@"de-DE"];
    } else if ([languageTitle isEqualToString:@"Italian"]) {
        languageCode = [NSMutableString stringWithString:@"it-IT"];
    } else if ([languageTitle isEqualToString:@"Russian"]) {
        languageCode = [NSMutableString stringWithString:@"ru-RU"];
    }
    
    //On language change, also set the micClient to nil, so that it gets recreated:
    micClient = nil;
    
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Hides or displays the current mode control.
 * @param show Whether to show or hide the current mode control.
 */
-(void)showMenu:(BOOL)show {
    [self.radioGroup setHidden:!show];
    [self.quoteText setHidden:show];
}

/**
 * Handles the Click event of the startButton control.
 * @param sender The event sender
 */
-(IBAction)StartButton_Click:(id)sender {
    isTranslating = !isTranslating;
    if (isTranslating) {
        [self StartTranslating];
    }
}

-(void) StartTranslating {

    [textOnScreen setString:(@"")];
    [self setText: textOnScreen];
    [[self startButton] setEnabled:NO];
    
    [self showMenu:FALSE];
    
    [self logRecognitionStart];
    
    NSString *subscriptionKey = @"f57ee437811a4e96aa71328993cdc5b4";
    
    if (self.useMicrophone) {
        if (micClient == nil) {
            micClient = [SpeechRecognitionServiceFactory createMicrophoneClientWithIntent:(self.defaultLocale)
                                                                           withPrimaryKey:(subscriptionKey)
                                                                         withSecondaryKey:(subscriptionKey)
                                                                            withLUISAppID:(self.luisAppId)
                                                                           withLUISSecret:(self.luisSubscriptionID)
                                                                             withProtocol:(self)];
        }
        
        NSLog(@"Bool value: %d", isTranslating);
        OSStatus status = [micClient startMicAndRecognition];
        
        [self WriteLine: (@"Translating ...")];
        if (status) {
            [self WriteLine:[[NSString alloc] initWithFormat:(@"Error starting audio. %@"), ConvertSpeechErrorToString(status)]];
        }
    }
    
}

//- (id)initWithFrame:(CGRect)frame {
//    if (self = [super initWithFrame:frame]) {
//        [self setBackgroundColor:[UIColor clearColor]];
//    }
//    return self;
//}



/**
 * Logs the recognition start.
 */
-(void)logRecognitionStart {
    NSString* recoSource;
    if (self.useMicrophone) {
        recoSource = @"microphone";
    } else if (self.mode == SpeechRecognitionMode_ShortPhrase) {
        recoSource = @"short wav file";
    } else {
        recoSource = @"long wav file";
    }

    [self WriteLine:[[NSString alloc] initWithFormat:(@"\n--- Start speech recognition using %@ with %@ mode in %@ language ----\n\n"), 
        recoSource, 
        self.mode == SpeechRecognitionMode_ShortPhrase ? @"Short" : @"Long",
        self.defaultLocale]];
}


/**
 * Called when a final response is received.
 * @param response The final result.
 */
-(void)onFinalResponseReceived:(RecognitionResult*)response {
    bool isFinalDicationMessage = self.mode == SpeechRecognitionMode_LongDictation &&
                                                (response.RecognitionStatus == RecognitionStatus_EndOfDictation ||
                                                 response.RecognitionStatus == RecognitionStatus_DictationEndSilenceTimeout);
    if (nil != micClient && self.useMicrophone && ((self.mode == SpeechRecognitionMode_ShortPhrase) || isFinalDicationMessage)) {
        // we got the final result, so it we can end the mic reco.  No need to do this
        // for dataReco, since we already called endAudio on it as soon as we were done
        // sending all the data.
        [micClient endMicAndRecognition];
    }

    if ((self.mode == SpeechRecognitionMode_ShortPhrase) || isFinalDicationMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [[self startButton] setEnabled:YES];
        });
    }
      
    if (!isFinalDicationMessage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            RecognizedPhrase* phrase = response.RecognizedPhrase[0];
            NSString *translatedText = [self translateTranscription: (phrase.DisplayText)];
            NSLog(@"HERE I AM PRINTING!");
            NSLog(translatedText);
            [self WriteLine:translatedText];
        });
    }
}

-(NSString*)translateTranscription:(NSString*) transcribedText {
    
    NSString *source = @"en";
    NSString *target = @"de";
    
    FGTranslator *translator =
    [[FGTranslator alloc] initWithBingAzureClientId:@"we-ar"
                                             secret:@"Kb8Jwf0id7WNT6dbMlwscVgkpS/Sj8RtP+XhZaPOPbU="];
    
    [translator translateText:transcribedText
                   withSource:(NSString *)source
                       target:(NSString *)target
                   completion:^(NSError *error, NSString *translated, NSString *sourceLanguage)
     {
         if (error) {
             NSLog(@"translation failed with error: %@", error);
         }
         else {
//             NSLog(@"translated from %@: %@", sourceLanguage, translated);
             translation = [NSMutableString stringWithString:translated];
         }
     }];
    
    return translation;
}

/**
 * Called when a partial response is received
 * @param response The partial result.
 */
-(void)onPartialResponseReceived:(NSString*) response {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self RewriteLine:(@"--- Partial result received by onPartialResponseReceived ---")];
        [self RewriteLine:response];
    });
}

/**
 * Called when an error is received
 * @param errorMessage The error message.
 * @param errorCode The error code.  Refer to SpeechClientStatus for details.
 */
-(void)onError:(NSString*)errorMessage withErrorCode:(int)errorCode {
    dispatch_async(dispatch_get_main_queue(), ^{
        [[self startButton] setEnabled:YES];
        [self WriteLine:(@"--- Error received by onError ---")];
        [self WriteLine:[[NSString alloc] initWithFormat:(@"%@ %@"), errorMessage, ConvertSpeechErrorToString(errorCode)]];
        [self WriteLine:@""];
    });
}

/**
 * Called when the microphone status has changed.
 * @param recording The current recording state
 */
-(void)onMicrophoneStatus:(Boolean)recording {
    if (!recording) {
        [micClient endMicAndRecognition];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        if (!recording) {
            [[self startButton] setEnabled:YES];
        }
        [self WriteLine:[[NSString alloc] initWithFormat:(@"********* Microphone status: %d *********"), recording]];
    });
}

/**
 * Writes the line.
 * @param text The line to write.
 */
-(void)WriteLine:(NSString*)text {
    [textOnScreen appendString:(text)];
    [self setText:textOnScreen];
}

/**
 * Writes the line.
 * @param text The line to write.
 */
-(void)RewriteLine:(NSString*)text {
    [textOnScreen setString:(text)];
    [self setText:textOnScreen];
}

/**
 * Event handler for when the current mode has changed.
 * @param sender The sending caller.
 */
-(IBAction)RadioButton_Click:(id)sender {
    NSUInteger index = [self.buttonGroup indexOfObject:sender];
    for(NSUInteger i = 0; i < self.buttonGroup.count; ++i) {
        UNIVERSAL_BUTTON* buttonSel = (UNIVERSAL_BUTTON*)self.buttonGroup[i];
        UNIVERSAL_BUTTON_SETCHECKED(buttonSel, (index == i) ? TRUE : FALSE);
    }

    if (micClient != nil) {
        [micClient finalize];
        micClient = nil;
    }

    if (dataClient != nil) {
        [dataClient finalize];
        dataClient = nil;
    }

    [self showMenu:FALSE];
}

/**
 * Converts an integer error code to an error string.
 * @param errorCode The error code
 * @return The string representation of the error code.
 */
NSString* ConvertSpeechErrorToString(int errorCode) {
    switch ((SpeechClientStatus)errorCode) {
        case SpeechClientStatus_SecurityFailed:         return @"SpeechClientStatus_SecurityFailed";
        case SpeechClientStatus_LoginFailed:            return @"SpeechClientStatus_LoginFailed";
        case SpeechClientStatus_Timeout:                return @"SpeechClientStatus_Timeout";
        case SpeechClientStatus_ConnectionFailed:       return @"SpeechClientStatus_ConnectionFailed";
        case SpeechClientStatus_NameNotFound:           return @"SpeechClientStatus_NameNotFound";
        case SpeechClientStatus_InvalidService:         return @"SpeechClientStatus_InvalidService";
        case SpeechClientStatus_InvalidProxy:           return @"SpeechClientStatus_InvalidProxy";
        case SpeechClientStatus_BadResponse:            return @"SpeechClientStatus_BadResponse";
        case SpeechClientStatus_InternalError:          return @"SpeechClientStatus_InternalError";
        case SpeechClientStatus_AuthenticationError:    return @"SpeechClientStatus_AuthenticationError";
        case SpeechClientStatus_AuthenticationExpired:  return @"SpeechClientStatus_AuthenticationExpired";
        case SpeechClientStatus_LimitsExceeded:         return @"SpeechClientStatus_LimitsExceeded";
        case SpeechClientStatus_AudioOutputFailed:      return @"SpeechClientStatus_AudioOutputFailed";
        case SpeechClientStatus_MicrophoneInUse:        return @"SpeechClientStatus_MicrophoneInUse";
        case SpeechClientStatus_MicrophoneUnavailable:  return @"SpeechClientStatus_MicrophoneUnavailable";
        case SpeechClientStatus_MicrophoneStatusUnknown:return @"SpeechClientStatus_MicrophoneStatusUnknown";
        case SpeechClientStatus_InvalidArgument:        return @"SpeechClientStatus_InvalidArgument";
    }

    return [[NSString alloc] initWithFormat:@"Unknown error: %d\n", errorCode];
}

/**
 * Converts a Confidence value to a string
 * @param confidence The confidence value.
 * @return The string representation of the confidence enumeration.
 */
NSString* ConvertSpeechRecoConfidenceEnumToString(Confidence confidence) {
    switch (confidence) {
        case SpeechRecoConfidence_None:
            return @"None";

        case SpeechRecoConfidence_Low:
            return @"Low";

        case SpeechRecoConfidence_Normal:
            return @"Normal";

        case SpeechRecoConfidence_High:
            return @"High";
    }
}

/**
 * Event handler for when the user wants to display the list of modes.
 * @param sender The sending caller.
 */
-(IBAction)ChangeModeButton_Click:(id)sender {
    [self showMenu:TRUE];
}

/**
 * Action for low memory
 */
-(void)didReceiveMemoryWarning {
#if !defined(TARGET_OS_MAC)
    [super didReceiveMemoryWarning];
#endif
}

/**
 * Appends text to the edit control.
 * @param text The text to set.
 */
- (void)setText:(NSString*)text {
    UNIVERSAL_TEXTVIEW_SETTEXT(self.quoteText, text);
    [self.quoteText scrollRangeToVisible:NSMakeRange([text length] - 1, 1)]; 
}




////////////////////////////////////////////////////////////////////////////


@synthesize videoDataOutput = _videoDataOutput;
@synthesize videoDataOutputQueue = _videoDataOutputQueue;

@synthesize borderImage = _borderImage;
@synthesize previewView = _previewView;
@synthesize previewLayer = _previewLayer;

@synthesize faceDetector = _faceDetector;

@synthesize isUsingFrontFacingCamera = _isUsingFrontFacingCamera;

- (void)setupAVCapture
{
    NSError *error = nil;
    
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone){
        [session setSessionPreset:AVCaptureSessionPreset640x480];
    } else {
        [session setSessionPreset:AVCaptureSessionPresetPhoto];
    }
    
    // Select a video device, make an input
    AVCaptureDevice *device;
    
    AVCaptureDevicePosition desiredPosition = AVCaptureDevicePositionFront;
    
    // find the front facing camera
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([d position] == desiredPosition) {
            device = d;
            self.isUsingFrontFacingCamera = YES;
            break;
        }
    }
    // fall back to the default camera.
    if( nil == device )
    {
        self.isUsingFrontFacingCamera = NO;
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    // get the input device
    AVCaptureDeviceInput *deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    
    if( !error ) {
        
        // add the input to the session
        if ( [session canAddInput:deviceInput] ){
            [session addInput:deviceInput];
        }
        
        
        // Make a video data output
        self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
        
        // we want BGRA, both CoreGraphics and OpenGL work well with 'BGRA'
        NSDictionary *rgbOutputSettings = [NSDictionary dictionaryWithObject:
                                           [NSNumber numberWithInt:kCMPixelFormat_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
        [self.videoDataOutput setVideoSettings:rgbOutputSettings];
        [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // discard if the data output queue is blocked
        
        // create a serial dispatch queue used for the sample buffer delegate
        // a serial dispatch queue must be used to guarantee that video frames will be delivered in order
        // see the header doc for setSampleBufferDelegate:queue: for more information
        self.videoDataOutputQueue = dispatch_queue_create("VideoDataOutputQueue", DISPATCH_QUEUE_SERIAL);
        [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoDataOutputQueue];
        
        if ( [session canAddOutput:self.videoDataOutput] ){
            [session addOutput:self.videoDataOutput];
        }
        
        // get the output for doing face detection.
        [[self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo] setEnabled:YES];
        
        self.previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:session];
        self.previewLayer.backgroundColor = [[UIColor blackColor] CGColor];
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspect;
        
        CALayer *rootLayer = [self.previewView layer];
        [rootLayer setMasksToBounds:YES];
        [self.previewLayer setFrame:[rootLayer bounds]];
        [rootLayer addSublayer:self.previewLayer];
        [session startRunning];
        
    }
    session = nil;
    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:
                                  [NSString stringWithFormat:@"Failed with error %d", (int)[error code]]
                                                            message:[error localizedDescription]
                                                           delegate:nil
                                                  cancelButtonTitle:@"Dismiss"
                                                  otherButtonTitles:nil];
        [alertView show];
        [self teardownAVCapture];
    }
}

// clean up capture setup
- (void)teardownAVCapture
{
    self.videoDataOutput = nil;
    if (self.videoDataOutputQueue) {
        // dispatch_release(self.videoDataOutputQueue);
    }
    [self.previewLayer removeFromSuperlayer];
    self.previewLayer = nil;
}


// utility routine to display error aleart if takePicture fails
- (void)displayErrorOnMainQueue:(NSError *)error withMessage:(NSString *)message
{
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:[NSString stringWithFormat:@"%@ (%d)", message, (int)[error code]]
                                  message:[error localizedDescription]
                                  delegate:nil
                                  cancelButtonTitle:@"Dismiss"
                                  otherButtonTitles:nil];
        [alertView show];
    });
}


// find where the video box is positioned within the preview layer based on the video size and gravity
+ (CGRect)videoPreviewBoxForGravity:(NSString *)gravity
                          frameSize:(CGSize)frameSize
                       apertureSize:(CGSize)apertureSize
{
    CGFloat apertureRatio = apertureSize.height / apertureSize.width;
    CGFloat viewRatio = frameSize.width / frameSize.height;
    
    CGSize size = CGSizeZero;
    if ([gravity isEqualToString:AVLayerVideoGravityResizeAspectFill]) {
        if (viewRatio > apertureRatio) {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        } else {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResizeAspect]) {
        if (viewRatio > apertureRatio) {
            size.width = apertureSize.height * (frameSize.height / apertureSize.width);
            size.height = frameSize.height;
        } else {
            size.width = frameSize.width;
            size.height = apertureSize.width * (frameSize.width / apertureSize.height);
        }
    } else if ([gravity isEqualToString:AVLayerVideoGravityResize]) {
        size.width = frameSize.width;
        size.height = frameSize.height;
    }
    
    CGRect videoBox;
    videoBox.size = size;
    if (size.width < frameSize.width)
        videoBox.origin.x = (frameSize.width - size.width) / 2;
    else
        videoBox.origin.x = (size.width - frameSize.width) / 2;
    
    if ( size.height < frameSize.height )
        videoBox.origin.y = (frameSize.height - size.height) / 2;
    else
        videoBox.origin.y = (size.height - frameSize.height) / 2;
    
    return videoBox;
}

// called asynchronously as the capture output is capturing sample buffers, this method asks the face detector
// to detect features and for each draw the green border in a layer and set appropriate orientation
- (void)drawFaces:(NSArray *)features
      forVideoBox:(CGRect)clearAperture
      orientation:(UIDeviceOrientation)orientation
{
    NSArray *sublayers = [NSArray arrayWithArray:[self.previewLayer sublayers]];
    NSInteger sublayersCount = [sublayers count], currentSublayer = 0;
    NSInteger featuresCount = [features count], currentFeature = 0;
    
    [CATransaction begin];
    [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
    // hide all the face layers
    for ( CALayer *layer in sublayers ) {
        if ( [[layer name] isEqualToString:@"FaceLayer"] )
            [layer setHidden:YES];
    }
    
    if ( featuresCount == 0 ) {
        [CATransaction commit];
        return; // early bail.
    }
    
    CGSize parentFrameSize = [self.previewView frame].size;
    NSString *gravity = [self.previewLayer videoGravity];
    
//    BOOL isMirrored = [self.previewLayer isVideoMirrored];
    CGRect previewBox = [ViewController videoPreviewBoxForGravity:gravity
                                                        frameSize:parentFrameSize
                                                     apertureSize:clearAperture.size];
    
    for ( CIFaceFeature *ff in features ) {
        // find the correct position for the square layer within the previewLayer
        // the feature box originates in the bottom left of the video frame.
        // (Bottom right if mirroring is turned on)
        CGRect faceRect = [ff bounds];
        
        // flip preview width and height
        CGFloat temp = faceRect.size.width;
        faceRect.size.width = faceRect.size.height;
        faceRect.size.height = temp;
        temp = faceRect.origin.x;
        faceRect.origin.x = faceRect.origin.y;
        faceRect.origin.y = temp;
        // scale coordinates so they fit in the preview box, which may be scaled
        CGFloat widthScaleBy = previewBox.size.width / clearAperture.size.height;
        CGFloat heightScaleBy = previewBox.size.height / clearAperture.size.width;
        faceRect.size.width *= widthScaleBy;
        faceRect.size.height *= heightScaleBy;
        faceRect.origin.x *= widthScaleBy;
        faceRect.origin.y *= heightScaleBy;
        
        //Added by Efe:
        faceRect.size.width *= 1;
        faceRect.size.height *= 1;
        faceRect.origin.x += faceRect.size.width * 0.7;
        faceRect.origin.y -= faceRect.size.height * 0.7;
        
        if ( false )
            faceRect = CGRectOffset(faceRect, previewBox.origin.x + previewBox.size.width - faceRect.size.width - (faceRect.origin.x * 2), previewBox.origin.y);
        else
            faceRect = CGRectOffset(faceRect, previewBox.origin.x, previewBox.origin.y);
        
        CALayer *featureLayer = nil;

//        CALayer *sublayer = [CALayer layer];
//        sublayer.shadowColor = [UIColor blackColor].CGColor;
//        sublayer.shadowOpacity = 0.8;
//        [featureLayer addSublayer:sublayer];
////        [CALayer resizeLayer:sublayer to:size];
//

        
//        CATextLayer *label = [[CATextLayer alloc] init];
//        [label setFont:@"Helvetica-Bold"];
//        [label setFontSize:20];
//        [label setFrame:validFrame];
//        [label setString:@"Hello"];
//        [label setAlignmentMode:kCAAlignmentCenter];
//        [label setForegroundColor:[[UIColor clearColor] CGColor]];
//        [featureLayer insertSublayer:label Above:layer];
//        
//        [label release];
        
        // re-use an existing layer if possible
        while ( !featureLayer && (currentSublayer < sublayersCount) ) {
            CALayer *currentLayer = [sublayers objectAtIndex:currentSublayer++];
            if ( [[currentLayer name] isEqualToString:@"FaceLayer"] ) {
                featureLayer = currentLayer;
                [currentLayer setHidden:NO];
            }
        }

        // note: replace "ImageUtils" with the class where you pasted the method above
        UIImage *imageWithText = [ViewController drawText:@"Some text"
                                        inImage:self.borderImage
                                        atPoint:CGPointMake(0, 0)];
        
        // create a new one if necessary
        if ( !featureLayer ) {
            featureLayer = [[CALayer alloc]init];
            featureLayer.contents = (id)imageWithText.CGImage;
            featureLayer.contents = (id)self.borderImage.CGImage;
            [featureLayer setName:@"FaceLayer"];
 
            CATextLayer *TextLayer = [CATextLayer layer];
            TextLayer.string = @"Test";
//            TextLayer.font = [UIFont boldSystemFontOfSize:18].fontName;
            TextLayer.backgroundColor = [UIColor blackColor].CGColor;
            TextLayer.position = CGPointMake(80.0, 80.0f);
            TextLayer.wrapped = NO;
            [featureLayer addSublayer:TextLayer];
            
//            CATextLayer *label = [[CATextLayer alloc] init];
//            [label setFontSize:20];
////            [label setFrame: featureLayer.frame];
//            [label setString:@"Hello, do you see that?"];
////            [label setAlignmentMode:kCAAlignmentCenter];
//            [label setForegroundColor:[[UIColor redColor] CGColor]];
//            [featureLayer addSublayer:label];
            
            [self.previewLayer addSublayer:featureLayer];
            
            featureLayer = nil;
        }
        [featureLayer setFrame:faceRect];
        
        switch (orientation) {
            case UIDeviceOrientationPortrait:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(0.))];
                break;
            case UIDeviceOrientationPortraitUpsideDown:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(180.))];
                break;
            case UIDeviceOrientationLandscapeLeft:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(90.))];
                break;
            case UIDeviceOrientationLandscapeRight:
                [featureLayer setAffineTransform:CGAffineTransformMakeRotation(DegreesToRadians(-90.))];
                break;
            case UIDeviceOrientationFaceUp:
            case UIDeviceOrientationFaceDown:
            default:
                break; // leave the layer in its last known orientation
        }
        currentFeature++;
    }
    
    [CATransaction commit];
}


+(UIImage*) drawText:(NSString*) text
             inImage:(UIImage*)  image
             atPoint:(CGPoint)   point
{
    UIGraphicsBeginImageContextWithOptions(image.size, YES, 0.0f);
    [image drawInRect:CGRectMake(0,0,image.size.width/2,image.size.height/2)];
    CGRect rect = CGRectMake(point.x, point.y, image.size.width/2, image.size.height/2);
    
//    rect.backgroundColor = [UIColor clearColor];
//    
//    [UIImageView setBackgroundColor:[UIColor clearColor]];
////    [self frame setBackgroundColor:[UIColor clearColor]];
    
    [[UIColor whiteColor] set];
    
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSaveGState(context);
    //    CGRect a=self.frame;
    //    a.origin.x=0;
    //    a.origin.y=0;
        CGContextSetBlendMode(context, kCGBlendModeClear);
    //    CGContextSetFillColorWithColor(context, [UIColor blackColor].CGColor);
    //    CGContextAddRect(context, a);
        CGContextFillPath(context);
        CGContextRestoreGState(context);
    
    UIFont *font = [UIFont boldSystemFontOfSize:20];
    if([text respondsToSelector:@selector(drawInRect:withAttributes:)])
    {
        //iOS 7
        NSDictionary *att = @{NSFontAttributeName:font};
        [text drawInRect:rect withAttributes:att];
    }
    else
    {
        //legacy support
        [text drawInRect:CGRectIntegral(rect) withFont:font];
    }
    
    UIImage *newImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    //    self = [super initWithFrame:frame];
    //    if (self) {
    //        // Initialization code
    //        [self setBackgroundColor:[UIColor clearColor]];
    //    }
    //    return self;
    
    return newImage;
    
}

- (NSNumber *) exifOrientation: (UIDeviceOrientation) orientation
{
    int exifOrientation;
    /* kCGImagePropertyOrientation values
     The intended display orientation of the image. If present, this key is a CFNumber value with the same value as defined
     by the TIFF and EXIF specifications -- see enumeration of integer constants.
     The value specified where the origin (0,0) of the image is located. If not present, a value of 1 is assumed.
     
     used when calling featuresInImage: options: The value for this key is an integer NSNumber from 1..8 as found in kCGImagePropertyOrientation.
     If present, the detection will be done based on that orientation but the coordinates in the returned features will still be based on those of the image. */
    
    enum {
        PHOTOS_EXIF_0ROW_TOP_0COL_LEFT			= 1, //   1  =  0th row is at the top, and 0th column is on the left (THE DEFAULT).
        PHOTOS_EXIF_0ROW_TOP_0COL_RIGHT			= 2, //   2  =  0th row is at the top, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT      = 3, //   3  =  0th row is at the bottom, and 0th column is on the right.
        PHOTOS_EXIF_0ROW_BOTTOM_0COL_LEFT       = 4, //   4  =  0th row is at the bottom, and 0th column is on the left.
        PHOTOS_EXIF_0ROW_LEFT_0COL_TOP          = 5, //   5  =  0th row is on the left, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP         = 6, //   6  =  0th row is on the right, and 0th column is the top.
        PHOTOS_EXIF_0ROW_RIGHT_0COL_BOTTOM      = 7, //   7  =  0th row is on the right, and 0th column is the bottom.
        PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM       = 8  //   8  =  0th row is on the left, and 0th column is the bottom.
    };
    
    switch (orientation) {
        case UIDeviceOrientationPortraitUpsideDown:  // Device oriented vertically, home button on the top
            exifOrientation = PHOTOS_EXIF_0ROW_LEFT_0COL_BOTTOM;
            break;
        case UIDeviceOrientationLandscapeLeft:       // Device oriented horizontally, home button on the right
            if (self.isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            break;
        case UIDeviceOrientationLandscapeRight:      // Device oriented horizontally, home button on the left
            if (self.isUsingFrontFacingCamera)
                exifOrientation = PHOTOS_EXIF_0ROW_TOP_0COL_LEFT;
            else
                exifOrientation = PHOTOS_EXIF_0ROW_BOTTOM_0COL_RIGHT;
            break;
        case UIDeviceOrientationPortrait:            // Device oriented vertically, home button on the bottom
        default:
            exifOrientation = PHOTOS_EXIF_0ROW_RIGHT_0COL_TOP;
            break;
    }
    return [NSNumber numberWithInt:exifOrientation];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    // get the image
    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CFDictionaryRef attachments = CMCopyDictionaryOfAttachments(kCFAllocatorDefault, sampleBuffer, kCMAttachmentMode_ShouldPropagate);
    CIImage *ciImage = [[CIImage alloc] initWithCVPixelBuffer:pixelBuffer
                                                      options:(__bridge NSDictionary *)attachments];
    if (attachments) {
        CFRelease(attachments);
    }
    
    // make sure your device orientation is not locked.
    UIDeviceOrientation curDeviceOrientation = [[UIDevice currentDevice] orientation];
    
    NSDictionary *imageOptions = nil;
    
    imageOptions = [NSDictionary dictionaryWithObject:[self exifOrientation:curDeviceOrientation] 
                                               forKey:CIDetectorImageOrientation];
    
    NSArray *features = [self.faceDetector featuresInImage:ciImage 
                                                   options:imageOptions];
    
    // get the clean aperture
    // the clean aperture is a rectangle that defines the portion of the encoded pixel dimensions
    // that represents image data valid for display.
    CMFormatDescriptionRef fdesc = CMSampleBufferGetFormatDescription(sampleBuffer);
    CGRect cleanAperture = CMVideoFormatDescriptionGetCleanAperture(fdesc, false /*originIsTopLeft == false*/);
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {
        [self drawFaces:features 
            forVideoBox:cleanAperture 
            orientation:curDeviceOrientation];
    });
}


- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    [self teardownAVCapture];
    self.faceDetector = nil;
    self.borderImage = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // We support only Portrait.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

@end
