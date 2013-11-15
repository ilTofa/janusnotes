//
//  FloatingWindow.h
//
//  Created by Giacomo Tufano on 15/12/09.
//
//  Copyright 2011, Giacomo Tufano (gt@ilTofa.it)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@protocol MicrophoneWindowDelegate
-(void)recordingCancelled;
-(void)recordingOK:(NSString *)recordingFilename;
@end


@interface MicrophoneWindow : UIViewController <AVAudioRecorderDelegate, AVAudioPlayerDelegate> 
{
}

@property (weak, nonatomic) IBOutlet UITextView *theText;
@property (weak, nonatomic) IBOutlet UIImageView *background;
@property (weak, nonatomic) IBOutlet UIButton *bAction;
@property (weak, nonatomic) IBOutlet UIButton *bOK;
@property (weak, nonatomic) IBOutlet UIButton *bCancel;
@property (retain, nonatomic) NSString *textString;
@property (weak, nonatomic) id<MicrophoneWindowDelegate> delegate;
@property (retain, nonatomic) NSURL *recordingURL;
@property BOOL bRecorded;
@property BOOL bRecording;
@property BOOL bPlaying;
@property (strong, nonatomic) AVAudioRecorder *theRecorder;
@property (strong, nonatomic) AVAudioPlayer *thePlayer;

-(IBAction)saveIt;
-(IBAction)cancelIt;
-(IBAction)doIt;

@end
