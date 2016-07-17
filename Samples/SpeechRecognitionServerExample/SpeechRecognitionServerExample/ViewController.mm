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

@end
