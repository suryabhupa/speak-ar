//
//  ViewController.h
//  vid2
//
//  Created by Mehmet Efe Akengin on 7/16/16.
//  Copyright © 2016 Efe. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <MobileCoreServices/MobileCoreServices.h>
@interface ViewController : UIViewController
@property (strong, nonatomic) NSURL *videoURL;
@property (strong, nonatomic) MPMoviePlayerController *videoController;
- (IBAction)captureVideo:(id)sender;
@end

