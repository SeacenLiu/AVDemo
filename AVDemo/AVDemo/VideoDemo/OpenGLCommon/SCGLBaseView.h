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

/** 上下文队列 */
@property (nonatomic, strong) dispatch_queue_t contextQueue;
/** 背景宽度 */
@property (nonatomic, assign) GLint            backingWidth;
/** 背景高度 */
@property (nonatomic, assign) GLint            backingHeight;

/** 触发渲染操作 */
- (void)render;
/** 释放gl资源 */
- (void)destroy;

/** 用于绑定EAGLContext，确保后续的gl操作有效 */
- (void)bindEAGLContext;

/**
 * (需要重写)核心渲染逻辑
 * - 重写该方法可插入核心gl渲染逻辑
 * - 该方法默认执行前都已经绑定好EAGLContext
 */
- (void)coreRender;

@end

NS_ASSUME_NONNULL_END
