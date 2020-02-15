//
//  PngPreviewViewController.m
//  AVDemo
//
//  Created by SeacenLiu on 2020/2/14.
//  Copyright © 2020 SeacenLiu. All rights reserved.
//

#import "PngPreviewViewController.h"
#import "PngPreviewController.h"
#import "NSString+Path.h"

@interface PngPreviewViewController ()

@end

@implementation PngPreviewViewController

- (IBAction)showBtnClick:(UIButton *)sender {
    NSString *path = [NSString bundlePath:@"test.png"];
    PngPreviewController *vc = [PngPreviewController viewControllerWithContentPath:path contentFrame:self.view.bounds];
    [[self navigationController] pushViewController:vc animated:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

@end
