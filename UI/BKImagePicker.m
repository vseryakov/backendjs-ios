//
//  BKImagePickerController.m
//
//  Created by Vlad Seryakov on 7/20/14.
//  Copyright (c) 2014. All rights reserved.
//

#import "BKViewController.h"
#import "BKImagePicker.h"

@interface BKImagePickerController () <UICollectionViewDataSource,UICollectionViewDelegate,UICollectionViewDelegateFlowLayout>
@end

@implementation BKImagePickerController {
    NSMutableArray *_photosItems;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self addTable];
    [self addToolbar:@"Albums" params:nil];
    
    _photosItems = [@[] mutableCopy];
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.scrollDirection = UICollectionViewScrollDirectionVertical;
    layout.sectionInset = UIEdgeInsetsMake(8, 8, 8, 8);
    layout.minimumInteritemSpacing = 8;
    layout.minimumLineSpacing = 8;
    int w = (self.tableView.width - layout.minimumInteritemSpacing * 5)/4;
    layout.itemSize = CGSizeMake(w, w);
    
    self.photosView = [[UICollectionView alloc] initWithFrame:self.tableView.frame collectionViewLayout:layout];
    self.photosView.backgroundColor = [BKui makeColor:self.view.backgroundColor h:1 s:1 b:0.95 a:1];
    self.photosView.showsHorizontalScrollIndicator = NO;
    self.photosView.showsVerticalScrollIndicator = YES;
    [self.photosView registerClass:[UICollectionViewCell class] forCellWithReuseIdentifier:@"cell"];
    [self.photosView setDataSource:self];
    [self.photosView setDelegate:self];
    [self.view addSubview:self.photosView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.photosView.x = self.view.width;
    self.toolbarTitle.text = @"Albums";
    [self getItems];
}

- (void)onBack:(id)sender
{
    if (self.photosView.x == 0) {
        [UIView animateWithDuration:0.3 delay:0 options:0
                         animations:^{ self.photosView.x = self.view.width; }
                         completion:^(BOOL finsihed) {
                             self.toolbarTitle.text = @"Albums";
                         }];
    } else {
        [self showPrevious];
    }
}

#pragma mark Albums table

- (void)getItems
{
    [self.items removeAllObjects];
    for (id account in self.params[@"accounts"]) {
        [self getAlbums:account];
    }
}

- (void)getAlbums:(id)obj
{
    [self showActivity];
    if ([obj isKindOfClass:[BKSocialAccount class]]) {
        BKSocialAccount *account = obj;
        [account getAlbums:nil success:^(id alist) {
            [self hideActivity];
            for (id item in alist) [self.items addObject:item];
            [self reloadTable];
        } failure:^(NSInteger code, NSString *reason) {
            [self hideActivity];
        }];
    }
}

- (void)onTableSelect:(NSIndexPath *)indexPath selected:(BOOL)selected
{
    if (!selected) return;
    NSDictionary *item = [self getItem:indexPath];
    [self getPhotos:item];
}

- (void)onTableCell:(UITableViewCell *)cell indexPath:(NSIndexPath *)indexPath
{
    cell.backgroundColor = [UIColor whiteColor];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    NSDictionary *item = [self getItem:indexPath];
    
    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(cell.height + 20, 0, cell.width - cell.height*2, cell.height)];
    label.text = item[@"name"];
    label.textColor = [UIColor darkTextColor];
    [cell addSubview:label];
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(10, 5, cell.height-10, cell.height-10)];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    [cell addSubview:imageView];
    
    [BKjs getImage:item[@"icon"] options:BKCacheModeCache success:^(UIImage *image, NSString *url) { imageView.image = image; } failure:nil];
}

#pragma mark Photos scrollview

- (void)getPhotos:(NSDictionary*)album
{
    [_photosItems removeAllObjects];
    [self.photosView reloadData];

    [UIView animateWithDuration:0.3 delay:0 options:0
                     animations:^{
                         self.photosView.x = 0;
                     }
                     completion:^(BOOL finished) {
                         self.toolbarTitle.text = album[@"name"];
                     }];
    
    // Photos to be retrieved from the remote accounts
    for (id item in self.params[@"accounts"]) {
        if ([item isKindOfClass:[BKSocialAccount class]]) {
            BKSocialAccount *account = item;
            if ([album[@"type"] isEqual:account.name]) {
                [account getPhotos:album params:nil success:^(id list) {
                    [_photosItems addObjectsFromArray:list];
                    [self.photosView reloadData];
                    Logger(@"%@: %d", account.name, (int)_photosItems.count);
                } failure:nil];
            }
        }
    }
}

- (void)onSelected:(NSInteger)index view:(UIImageView*)view
{
    NSDictionary *item = _photosItems[index];
    for (id key in item) self.params[key] = item[key];

    ControllerBlock block = self.params[@"_block"];
    if (block) {
        block(self, self.params);
        [self showPrevious];
    } else
    if (self.delegate) {
        [self.delegate onImagePicker:self image:item[@"_image"] params:self.params];
        [self showPrevious];
    } else {
        [self showPrevious];
    }
}

# pragma mark - UICollectionView Datasource

- (NSInteger)collectionView:(UICollectionView *)view numberOfItemsInSection:(NSInteger)section
{
    return _photosItems.count;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return 1;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    NSMutableDictionary *item = [_photosItems[indexPath.row] mutableCopy];
    
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"cell" forIndexPath:indexPath];
    cell.clipsToBounds = YES;
    
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, cell.width, cell.width)];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.tag = 1000;
    [cell addSubview:imageView];
    
    [BKjs getImage:item[@"icon"] options:BKCacheModeCache success:^(UIImage *image, NSString *url) {
        imageView.image = image;
        item[@"_image"] = image;
        [_photosItems setObject:item atIndexedSubscript:indexPath.row];
    } failure:nil];
    return cell;
}

# pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    __weak UIImageView *imageView = (UIImageView*)[cell viewWithTag:1000];
    
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionOverrideInheritedDuration|UIViewAnimationOptionOverrideInheritedCurve
                     animations:^{
                         imageView.alpha = 0.5;
                     }
                     completion:^(BOOL status) {
                         [self onSelected:indexPath.row view:imageView];
                     }];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    __weak UIImageView *imageView = (UIImageView*)[cell viewWithTag:1000];
    
    [UIView animateWithDuration:0.2 delay:0 options:UIViewAnimationOptionOverrideInheritedDuration|UIViewAnimationOptionOverrideInheritedCurve
                     animations:^{
                         imageView.alpha = 1.0;
                     }
                     completion:nil];
}

@end
