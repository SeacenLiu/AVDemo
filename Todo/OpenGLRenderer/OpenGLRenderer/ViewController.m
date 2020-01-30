//
//  ViewController.m
//  OpenGLRenderer
//
//  Created by SeacenLiu on 2019/11/15.
//  Copyright © 2019 SeacenLiu. All rights reserved.
//

#import "ViewController.h"
#import "./utils/CommonUtil.h"
#import "PngPreviewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (IBAction)displayClick:(id)sender {
    NSString *path = [CommonUtil bundlePath:@"1.png"];
    PngPreviewController *vc = [PngPreviewController viewControllerWithContentPath:path contentFrame:self.view.bounds];
    [[self navigationController] pushViewController:vc animated:YES];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}


@end
