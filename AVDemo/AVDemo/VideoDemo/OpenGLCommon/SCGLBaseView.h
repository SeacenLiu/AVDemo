//
//  SCGLBaseView.h
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/17.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface SCGLBaseView : UIView

@property (nonatomic, strong) dispatch_queue_t contextQueue;
@property (nonatomic, assign) GLint            backingWidth;
@property (nonatomic, assign) GLint            backingHeight;

- (BOOL)prepareRender;
- (void)render;
- (void)coreRender;
- (void)destroy;

@end

NS_ASSUME_NONNULL_END
