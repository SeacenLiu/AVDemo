//
//  ELImageInput.h
//  VideoToolboxEncoder
//
//  Created by SeacenLiu on 2019/12/30.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#ifndef ELImageInput_h
#define ELImageInput_h

@protocol ELImageInput <NSObject>

- (void)newFrameReadyAtTime:(CMTime)frameTime timimgInfo:(CMSampleTimingInfo)timimgInfo;
- (void)setInputTexture:(ELImageTextureFrame *)textureFrame;

@end

#endif /* ELImageInput_h */
