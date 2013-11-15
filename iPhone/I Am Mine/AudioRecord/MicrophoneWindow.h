//
//  FloatingWindow.h
//
//  Created by Giacomo Tufano on 15/12/09.
//
//  Copyright (c) 2011 Giacomo Tufano. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
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
