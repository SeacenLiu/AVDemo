//
//  AudioRecorder+Interruption.h
//  AudioRecorder
//
//  Created by SeacenLiu on 2019/12/5.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "AudioRecorder.h"

@interface AudioRecorder (Interruption)

- (void)addAudioSessionInterruptedObserver;

@end

