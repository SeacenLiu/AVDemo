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

/** 触发渲染操作 */
- (void)render;
/** 释放gl资源 */
- (void)destroy;

/**
 * (需要重写)核心渲染逻辑
 * - 重写该方法可插入核心gl渲染逻辑
 * - 该方法默认执行前都会绑定好EAGLContext
 */
- (void)coreRender;

/** 用于绑定EAGLContext，确保后续的gl操作有效 */
- (void)bindEAGLContext;

@end

NS_ASSUME_NONNULL_END
