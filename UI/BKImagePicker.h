//
//  BKImagePicker.h
//
//  Created by Vlad Seryakov on 7/20/14.
//  Copyright (c) 2014. All rights reserved.
//

@interface BKImagePickerController : BKViewController
@property (nonatomic, strong) UICollectionView *photosView;
@property (nonatomic, assign) BKViewController *pickerDelegate;
@end

