//
//  OSStatusHelp.h
//  AudioRecorder
//
//  Created by SeacenLiu on 2019/12/5.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#ifndef OSStatusHelp_h
#define OSStatusHelp_h

static void CheckStatus(OSStatus status, NSString *message, BOOL fatal)
{
    if(status != noErr)
    {
        char fourCC[16];
        *(UInt32 *)fourCC = CFSwapInt32HostToBig(status);
        fourCC[4] = '\0';
        
        if(isprint(fourCC[0]) && isprint(fourCC[1]) && isprint(fourCC[2]) && isprint(fourCC[3]))
            NSLog(@"%@: %s", message, fourCC);
        else
            NSLog(@"%@: %d", message, (int)status);
        
        if(fatal)
            exit(-1);
    }
}

#endif /* OSStatusHelp_h */
