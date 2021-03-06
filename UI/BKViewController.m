//
//  BKViewController.m
//
//  Created by Vlad Seryakov on 7/4/14.
//  Copyright (c) 2013. All rights reserved.
//

#import "BKViewController.h"
#import "BKImagePicker.h"

@interface ImagePicker: NSObject <UIImagePickerControllerDelegate,UINavigationControllerDelegate>
@property (strong, nonatomic) BKViewController *view;
@property (strong, nonatomic) UIImagePickerController *picker;
@property (strong, nonatomic) NSDictionary *params;
- (id)initWithView:(BKViewController*)view;
@end;

@interface BKViewController () <UIViewControllerTransitioningDelegate,UINavigationControllerDelegate,
                                UIGestureRecognizerDelegate,UITableViewDelegate,UITableViewDataSource,
                                UITextFieldDelegate,UITextViewDelegate,UISearchBarDelegate>
@property (nonatomic, strong) UIPercentDrivenInteractiveTransition *interactionController;
@end

@implementation BKViewController {
    int _activityCount;
    CGPoint _center;
    CGRect _drawerFrame;
    BOOL _panStarted;
    NSTimer *_searchTimer;
    ImagePicker *_picker;
    UIView *_panView;
    NSTimer *_timer;
}

+ (BKViewController*)activeController
{
    UIViewController *root = [BKui rootViewController];
    if ([root isKindOfClass:[BKViewController class]]) return (BKViewController*)root;
    return nil;
}

- (instancetype)init
{
    self = [super init];
    _activityCount = 0;
    self.params = [@{} mutableCopy];
    self.items = [@[] mutableCopy];
    self.transition = [@{} mutableCopy];
    self.barStyle = UIStatusBarStyleDefault;
    self.toolbarHeight = 44;
    self.barHeight = 20;
    self.tableRows = 0;
    self.tableCell = nil;
    self.tableSearchHidden = YES;
    self.drawerPanning = YES;
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
   
    self.activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.activityView.layer.backgroundColor = [[UIColor colorWithWhite:0.0f alpha:0.1f] CGColor];
    self.activityView.hidden = YES;
    self.activityView.hidesWhenStopped = YES;
    self.activityView.frame = CGRectMake(0, 0, 56, 56);
    self.activityView.layer.masksToBounds = YES;
    self.activityView.layer.cornerRadius = 8;
    [self.view addSubview:self.activityView];
    [BKui setStyle:self.activityView style:BKui.style[@"activity"]];

    self.view.backgroundColor = [UIColor whiteColor];

    self.automaticallyAdjustsScrollViewInsets = NO;
    self.navigationController.navigationBarHidden = YES;
    self.extendedLayoutIncludesOpaqueBars = YES;
    [self setNeedsStatusBarAppearanceUpdate];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
    self.navigationController.interactivePopGestureRecognizer.delegate = self;
    
    // Do not preserve selection
    if (self.tableShowUnselected) [self unselectTable];
    if (self.tableSearchHidden && self.tableSearchable) {
        self.tableView.contentOffset = CGPointMake(0, self.tableView.tableHeaderView.height);
    }
    self.activityView.center = self.view.center;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.activityView.center = self.view.center;
    [self.view bringSubviewToFront:self.activityView];
    if (!self.subscribeAlways) {
        [self subscribe];
    }
    if (self.timerInterval) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:self.timerInterval
                                                  target:self
                                                selector:@selector(onTimer:)
                                                userInfo:nil
                                                 repeats:YES];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self saveTablePosition:nil];
    self.navigationController.navigationBarHidden = YES;
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    if (!self.subscribeAlways) {
        [self unsubscribe];
    }
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    self.navigationController.delegate = nil;
}

- (void)dealloc
{
    [self unsubscribe];
}

- (void)addInfoView:(NSString*)text
{
    if (!self.infoView) {
        int y = self.tableView ? self.tableView.y : (int)self.toolbarHeight + (int)self.barHeight;
        int h = self.tableView ? self.tableView.height : self.view.height - y;
        self.infoView = [[UIView alloc] initWithFrame:CGRectMake(0, y, self.view.width, h)];
        self.infoView.backgroundColor = self.view.backgroundColor;
        self.infoView.hidden = YES;
        [self.view addSubview:self.infoView];
        [BKui setStyle:self.infoView style:BKui.style[@"info"]];
    
        self.infoTextView = [[UITextView alloc] initWithFrame:self.infoView.bounds];
        [self.infoView addSubview:self.infoTextView];
        self.infoTextView.scrollEnabled = NO;
        self.infoTextView.textColor = [UIColor grayColor];
        self.infoTextView.font = [UIFont systemFontOfSize:18];
        self.infoTextView.userInteractionEnabled = YES;
        self.infoTextView.selectable = YES;
        self.infoTextView.editable = NO;
        self.infoTextView.delegate = self;
        self.infoTextView.textContainerInset = UIEdgeInsetsMake(20, 10, 20, 10);
        self.infoTextView.textAlignment = NSTextAlignmentCenter;
        [BKui setStyle:self.infoTextView style:BKui.style[@"info-text"]];
    } else {
        self.infoTextView.frame = self.infoView.bounds;
    }
    if (text) {
        self.infoTextView.text = text;
        [self.infoTextView sizeToFit];
        self.infoTextView.y = self.infoView.height/2 - self.infoTextView.height/2;
        self.infoTextView.centerX = self.view.centerX;
    }
}

- (void)addInfoView:(NSString*)text links:(NSArray*)links handler:(SuccessBlock)handler
{
    [self addInfoView:nil];
    [BKui setTextLinks:self.infoTextView text:text links:links handler:handler];
    [self.infoTextView sizeToFit];
    self.infoTextView.y = self.infoView.height/2 - self.infoTextView.height/2;
    self.infoTextView.centerX = self.view.centerX;
}

#pragma mark Toolbar

- (void)addToolbar:(NSString*)title params:(NSDictionary*)params
{
    if (!self.toolbarView) {
        self.toolbarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, self.toolbarHeight + self.barHeight)];
        self.toolbarView.userInteractionEnabled = YES;
        self.toolbarView.backgroundColor = [BKui makeColor:self.view.backgroundColor h:1 s:1 b:0.95 a:1];
        [self.view addSubview:self.toolbarView];
        
        self.toolbarBack = [BKui makeCustomButton:@"Back" image:nil];
        self.toolbarBack.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        self.toolbarBack.frame = CGRectMake(10, self.barHeight, self.toolbarView.height, self.toolbarView.height - self.barHeight);
        [self.toolbarBack addTarget:self action:@selector(onBack:) forControlEvents:UIControlEventTouchUpInside];
        [self.toolbarView addSubview:self.toolbarBack];
        
        self.toolbarTitle = [[UILabel alloc] initWithFrame:CGRectMake(self.toolbarView.height, self.barHeight, self.toolbarView.width-self.toolbarView.height*2, self.toolbarView.height - self.barHeight)];
        self.toolbarTitle.textAlignment = NSTextAlignmentCenter;
        self.toolbarTitle.centerY = self.toolbarView.height/2 + self.barHeight/2;
        [self.toolbarView addSubview:self.toolbarTitle];
        
        self.toolbarNext = [BKui makeCustomButton:@"Next" image:nil];
        self.toolbarNext.contentHorizontalAlignment = UIControlContentHorizontalAlignmentRight;
        self.toolbarNext.frame = CGRectMake(self.toolbarView.width - self.toolbarView.height - self.barHeight/2, self.barHeight, self.toolbarView.height, self.toolbarView.height - self.barHeight);
        self.toolbarNext.hidden = YES;
        [self.toolbarNext addTarget:self action:@selector(onNext:) forControlEvents:UIControlEventTouchUpInside];
        [self.toolbarView addSubview:self.toolbarNext];
    }
    self.toolbarTitle.text = title ? title : @"";
    [BKui setStyle:self.toolbarView style:BKui.style[@"toolbar"]];
    [BKui setStyle:self.toolbarTitle style:BKui.style[@"toolbar-title"]];
    [BKui setStyle:self.toolbarBack style:BKui.style[@"toolbar-back"]];
    [BKui setStyle:self.toolbarNext style:BKui.style[@"toolbar-next"]];
}

#pragma mark Menubar

- (void)addMenubar:(NSArray*)items params:(NSDictionary*)params
{
    self.navigationController.navigationBarHidden = YES;
    if (self.menubarView) {
        [self.menubarView setMenu:items params:params];
    } else {
        self.menubarView = [[BKMenubarView alloc] init:CGRectMake(0, 0, self.view.width, self.toolbarHeight + self.barHeight) items:nil params:nil];
        self.menubarView.contentInsets = UIEdgeInsetsMake(self.barHeight, 0, 0, 0);
        self.menubarView.delegate = self;
        [self.view addSubview:self.menubarView];
        [self.menubarView setMenu:items params:params];
        self.menubarView.backgroundColor = [BKui makeColor:self.view.backgroundColor h:1 s:1 b:0.95 a:1];
        [BKui setStyle:self.menubarView style:BKui.style[@"menubar"]];
    }
}

- (void)updateMenubar:(NSDictionary*)params
{
    if (self.menubarView) [self.menubarView update:params];
}

#pragma mark Tabbar

- (void)addTabbar:(NSArray*)items params:(NSDictionary*)params
{
    if (self.tabbarView) {
        [self.tabbarView setMenu:items params:params];
    } else {
        self.tabbarView = [[BKMenubarView alloc] init:CGRectMake(0, self.view.height - self.toolbarHeight, self.view.width, self.toolbarHeight) items:items params:params];
        self.tabbarView.backgroundColor = [BKui makeColor:self.view.backgroundColor h:1 s:1 b:0.95 a:1];
        self.tabbarView.delegate = self;
        [BKui setViewShadow:self.tabbarView color:nil offset:CGSizeMake(0, 0.5) opacity:0.5 radius:-1];
        [self.view addSubview:self.tabbarView];
    }
}

#pragma mark Table

- (void)addTable
{
    if (self.tableView) return;
    CGRect frame = CGRectMake(0, self.toolbarHeight + self.barHeight, self.view.width, self.view.height - self.toolbarHeight - self.barHeight);
    self.tableView = [[UITableView alloc] initWithFrame:frame];
    self.tableView.separatorInset = UIEdgeInsetsZero;
    self.tableView.delegate = (id<UITableViewDelegate>)self;
    self.tableView.dataSource = (id<UITableViewDataSource>)self;
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.bouncesZoom = YES;
    self.tableView.delaysContentTouches = YES;
    self.tableView.canCancelContentTouches = YES;
    self.tableView.showsHorizontalScrollIndicator = NO;
    self.tableView.showsVerticalScrollIndicator = YES;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    self.tableView.rowHeight = 44;
    if ([self.tableView respondsToSelector:@selector(setLayoutMargins:)]) [self.tableView setLayoutMargins:UIEdgeInsetsZero];
    
    if (self.tableTransparent) {
        self.tableView.backgroundColor = [UIColor clearColor];
    }
    
    if (!self.tableSearchNames) {
        self.tableSearchNames = @[@"name", @"alias", @"email"];
    }
    self.tableSearchField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, self.toolbarHeight*0.75)];
    self.tableSearchField.placeholder = @"Search";
    self.tableSearchField.delegate = self;
    [BKui setStyle:self.tableSearchField style:BKui.style[@"search-text"]];

    self.tableSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, self.toolbarHeight)];
    self.tableSearchBar.placeholder = @"Search";
    self.tableSearchBar.delegate = self;
    if (self.tableSearchBarVisible) {
        self.tableSearchBar.y = self.tableView.y;
        [self.view addSubview:self.tableSearchBar];
        self.tableView.y = self.tableSearchBar.bottom;
        self.tableView.height -= self.tableSearchBar.height;
    } else
    if (self.tableSearchable) {
        self.tableView.tableHeaderView = self.tableSearchBar;
    }
    [BKui setStyle:self.tableSearchBar style:BKui.style[@"search-bar"]];
    
    self.tableRefresh = [[UIRefreshControl alloc]init];
    [self.tableRefresh addTarget:self action:@selector(refreshItems) forControlEvents:UIControlEventValueChanged];
    if (self.tableRefreshable) {
        [self.tableView addSubview:self.tableRefresh];
    }
    [self.view addSubview:self.tableView];
    [BKui setStyle:self.tableView style:BKui.style[@"table"]];
}

- (void)reloadTable
{
    if ([self.itemsAll isKindOfClass:[NSArray class]] && self.itemsAll != self.items) {
        self.items = [self filterItems:self.itemsAll];
    }
    Logger(@"%@: items: %d", self.name, (int)self.items.count + (int)self.tableRows);
    
    if (self.tableRefresh.isRefreshing) [self.tableRefresh endRefreshing];
    [self.tableView reloadData];
}

- (void)reloadItems:(NSArray*)items
{
    self.itemsAll = [items mutableCopy];
    [self.items removeAllObjects];
    [self reloadTable];
}

- (void)unselectTable
{
    if (!self.tableView) return;
    NSArray *rows = [self.tableView indexPathsForSelectedRows];
    for (NSIndexPath *path in rows) {
        [self onTableSelect:path selected:NO];
        [self.tableView deselectRowAtIndexPath:path animated:NO];
    }
}

- (void)clearItems
{
    self.itemsAll = nil;
    self.itemsNext = nil;
    self.itemsIndex = nil;
    self.itemsSection = nil;
    [self.items removeAllObjects];
}

- (void)getItems
{
}

- (void)refreshItems
{
    [self clearItems];
    [self getItems];
}

- (id)getItem:(NSIndexPath*)indexPath
{
    if (!indexPath) return nil;
    if (self.itemsSection) {
        NSArray *section = indexPath.section < self.itemsSection.count ? self.itemsSection[indexPath.section] : nil;
        return section && indexPath.row < [section count] ? section[indexPath.row] : nil;
    } else {
        NSInteger index = indexPath.row - self.tableRows;
        return index < [self.items count] ? self.items[index] : nil;
    }
}

- (void)setItem:(NSIndexPath*)indexPath data:(id)data
{
    if (!indexPath || !data) return;
    if (self.itemsSection) {
        NSMutableArray *section = indexPath.section < self.itemsSection.count ? self.itemsSection[indexPath.section] : nil;
        if (section && indexPath.row < [section count]) section[indexPath.row]  = data;
    } else {
        NSInteger index = indexPath.row - self.tableRows;
        if (index < [self.items count]) self.items[index] = data;
    }
}

- (void)restoreTablePosition
{
    if (!self.tableView || !self.tableRestore) return;
    float offset = [BKjs.params[[NSString stringWithFormat:@"tableTop:%@",self.name]] floatValue];
    [self.tableView setContentOffset:CGPointMake(0, offset -  self.tableView.contentInset.top) animated:NO];
    Debug(@"%g", offset);
}

- (void)saveTablePosition:(NSNumber*)pos
{
    if (!self.tableView) return;
    BKjs.params[[NSString stringWithFormat:@"tableTop:%@",self.name]] = pos ? pos : @(self.tableView.contentOffset.y);
}

- (void)scrollToRow:(int)row animated:(BOOL)animated
{
    double height = 0;
    for (int i = 0; i < row; i++) height += [self tableView:self.tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0]];
    [self.tableView setContentOffset:CGPointMake(self.tableView.contentOffset.x, height) animated:animated];
}

- (void)queueTableSearch
{
    if (_searchTimer) [_searchTimer invalidate];
    _searchTimer = [NSTimer timerWithTimeInterval:0.4 target:self selector:@selector(onTableSearch:) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:_searchTimer forMode:NSRunLoopCommonModes];
}

- (NSMutableArray*)filterItems:(NSArray*)items
{
    NSMutableArray *list = [@[] mutableCopy];
    if (![items isKindOfClass:[NSArray class]]) return list;
    Logger(@"text=%@, items=%d", self.searchText, (int)items.count);
    
    for (int i = 0; i < items.count; i++) {
        if (!self.searchText || !self.searchText.length) {
            [list addObject:items[i]];
        } else
        if ([items[i] isKindOfClass:[NSDictionary class]]) {
            NSDictionary *item = items[i];
            for (NSString *key in self.tableSearchNames) {
                if ([item[key] isKindOfClass:[NSString class]] && [item[key] rangeOfString:self.searchText options:NSCaseInsensitiveSearch].location != NSNotFound) {
                    [list addObject:item];
                }
            }
        }
    }
    [self buildIndex:list];
    return list;
}

- (void)buildIndex:(NSMutableArray*)list
{
}

- (void)onTableSearch:(id)sender
{
    Debug(@"%@, %d items, %d all", self.searchText, (int)[self.items count], (int)[self.itemsAll count]);
    
    // Clearing the text while the spell suggestion is up may clear but never calls the delegate
    if (![self.searchText isEqual:self.tableSearchBar.text]) self.tableSearchBar.text = self.searchText;
    if (![self.searchText isEqual:self.tableSearchField.text]) self.tableSearchField.text = self.searchText;
    
    if(self.itemsSection) {
        [self reloadTable];
        return;
    }
    
    [self.tableView beginUpdates];
    NSMutableArray *paths = [@[] mutableCopy];
    for (int i = 0; i < self.items.count; i++) [paths addObject:[NSIndexPath indexPathForRow:i+self.tableRows inSection:0]];
    [self.tableView deleteRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationNone];
    
    self.items = [self filterItems:self.itemsAll];
    paths = [@[] mutableCopy];
    for (int i = 0; i < self.items.count; i++) [paths addObject:[NSIndexPath indexPathForRow:i+self.tableRows inSection:0]];
    [self.tableView insertRowsAtIndexPaths:paths withRowAnimation:UITableViewRowAnimationFade];
    [self.tableView endUpdates];
}

- (void)hideKeyboard
{
    if (![self.view endEditing:YES]) {
        if (!self.tableView) return;
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[self.tableView indexPathForSelectedRow]];
        if (!cell) return;
        [cell endEditing:YES];
    }
}

- (void)onTimer:(NSTimer *)timer
{
}

#pragma mark Activity

- (void)showActivity
{
    self.activityView.hidden = NO;
    [self.view bringSubviewToFront:self.activityView];
    [self.activityView startAnimating];
}

- (void)hideActivity
{
    _activityCount = 0;
    [self.activityView stopAnimating];
    self.activityView.hidden = YES;
    if (self.tableRefresh.isRefreshing) [self.tableRefresh endRefreshing];
}

- (void)showActivity:(BOOL)incr
{
    if (incr) _activityCount++;
    [self showActivity];
}

- (void)hideActivity:(BOOL)decr
{
    if (decr) {
        _activityCount--;
        if (_activityCount > 0) return;
    }
    [self hideActivity];
}

#pragma mark Navigation

- (void)onBack:(id)sender
{
    [self showPrevious];
}

- (void)onNext:(id)sender
{
    if (self.nextControllerName) {
        [BKui showViewController:self name:self.nextControllerName params:self.params];
    }
}

- (UIViewController*)prevController
{
    if (self.navigationController.childViewControllers.count > 1) {
        return self.navigationController.childViewControllers[self.navigationController.childViewControllers.count - 2];
    }
    return nil;
}

- (void)showPrevious
{
    [self showPrevious:nil];
}

- (void)showPrevious:(NSDictionary*)params
{
    Logger(@"showPrevious: %@: %@ %@", self.name, self.navigationMode, self.prevControllerName);
    
    if ([self.navigationMode hasPrefix:@"drawer"]) {
        [self prepareForHide:params];
        [self hideDrawer];
        return;
    }
    
    if ([self.navigationMode isEqual:@"push"]) {
        [self prepareForHide:params];
        self.navigationController.delegate = self;
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    if ([self.navigationMode isEqual:@"modal"]) {
        [self prepareForHide:params];
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    // Replace with previous controller completely
    [BKui showViewController:self name:self.prevControllerName params:params];
}

- (void)showDrawer:(UIViewController*)owner
{
    CGRect frame = self.view.frame;
    
    // Screen capture the current content of the navigation view (along with the navigation bar, if any)
    UIImage *image = [BKui captureScreen:owner.view.window];
    
    // Sliding button with the screenshot
    if (self.drawerView) [self.drawerView removeFromSuperview];
    self.drawerView = [UIButton buttonWithType:UIButtonTypeCustom];
    self.drawerView.exclusiveTouch = YES;
    if (frame.origin.y > 0) {
        frame.size.height += frame.origin.y;
        frame.origin.y *= -1;
    }
    self.drawerView.frame = frame;
    [self.drawerView setImage:image forState:UIControlStateNormal];
    [self.drawerView setImage:image forState:UIControlStateHighlighted];
    self.drawerView.layer.shadowOffset = CGSizeZero;
    self.drawerView.layer.shadowRadius = 5;
    self.drawerView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.drawerView.layer.shadowOpacity = .5;
    self.drawerView.layer.shadowPath = [UIBezierPath bezierPathWithRect:owner.view.window.layer.bounds].CGPath;
    [self.drawerView addTarget:self action:@selector(showPrevious) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.drawerView];
    
    _drawerFrame = self.view.bounds;
    if ([self.navigationMode isEqual:@"drawerLeft"]) {
        _drawerFrame.origin.x = _drawerFrame.size.width + 5;
    }
    if ([self.navigationMode isEqual:@"drawerLeftAnchor"]) {
        _drawerFrame.origin.x = _drawerFrame.size.width - 40;
    }
    if ([self.navigationMode isEqual:@"drawerRight"]) {
        _drawerFrame.origin.x =  5 - _drawerFrame.size.width;
    }
    if ([self.navigationMode isEqual:@"drawerRightAnchor"]) {
        _drawerFrame.origin.x = 40 - _drawerFrame.size.width;
    }
    
    // Support swipe in addition to touch
    if (self.drawerPanning == YES && !self.drawerPanGesture) {
        self.drawerPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onDrawerPan:)];
        self.drawerPanGesture.delegate = self;
        [self.view addGestureRecognizer:self.drawerPanGesture];
    }
    
    [owner.navigationController pushViewController:self animated:NO];
    
    BKBounceAnimation *bounce = [[BKBounceAnimation alloc] initWithKeyPath:@"position.x" from:@(self.drawerView.center.x) to:@(_drawerFrame.origin.x + _drawerFrame.size.width/2) start:nil stop:nil];
    [bounce configure:self.drawerView];
}

- (void)hideDrawer
{
    if (![self.drawerView isKindOfClass:[UIView class]]) return;
    
    BKBounceAnimation *bounce = [[BKBounceAnimation alloc] initWithKeyPath:@"position.x" from:@(self.drawerView.center.x) to:@(self.view.center.x) start:nil stop:^(id anim) {
        [self.navigationController popViewControllerAnimated:NO];
        [self.drawerView removeFromSuperview];
        self.drawerView = nil;
    }];
    bounce.overshoot = NO;
    [bounce configure:self.drawerView];
}

- (void)prepareForShow:(UIViewController*)owner name:(NSString*)name mode:(NSString*)mode params:(NSDictionary*)params
{
    self.name = name;
    self.navigationMode = mode ? mode : @"";
    self.prevControllerName = [owner isKindOfClass:[BKViewController class]] ? [(BKViewController*)owner name] : @"";
    [self.params removeAllObjects];
    for (id key in params) self.params[key] = params[key];
    
    if (params && params[@"bk:transition"]) {
        if ([params[@"bk:transition"] isKindOfClass:[NSString class]]) {
            self.transition[@"type"] = params[@"bk:transition"];
        } else
        if ([params[@"bk:transition"] isKindOfClass:[NSDictionary class]]) {
            [self.transition removeAllObjects];
            for (id key in params[@"bk:transition"]) {
                self.transition[key] = params[@"bk:transition"][key];
            }
        }
        [self.params removeObjectForKey:@"bk:transition"];
    }
    
    if ([@[@"", @"push"] containsObject:self.navigationMode]) {
        owner.navigationController.delegate = self;
        self.navigationController.delegate = self;
        self.transitioningDelegate = nil;
    }
    
    if ([@[@"modal"] containsObject:self.navigationMode]) {
        self.navigationController.delegate = nil;
        self.transitioningDelegate = self;
        self.modalPresentationStyle = UIModalPresentationCustom;
    }
    
    Logger(@"%@: mode=%@, type=%@", self.name, self.navigationMode, self.transition[@"type"]);
}

- (void)prepareForHide:(NSDictionary*)params
{
    if ([[self prevController] isKindOfClass:[BKViewController class]]) {
        BKViewController *prev = (BKViewController*)[self prevController];
        for (id key in params) prev.params[key] = params[key];
        [prev prepareForReturn];
    }
}

- (void)prepareForReturn
{
    
}

- (void)onPan:(UIPanGestureRecognizer *)recognizer view:(UIView*)view right:(BOOL)right finish:(FinishBlock)finish
{
    CGPoint point = [recognizer translationInView:self.view];
    
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        _center = view.center;
        _panStarted = YES;
    } else
    if (_panStarted && recognizer.state == UIGestureRecognizerStateChanged) {
        if (_center.x + point.x >= self.view.width/2) {
            view.center = CGPointMake(_center.x + point.x, _center.y);
        }
    } else
    if (_panStarted && (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed)) {
        _panStarted = NO;
        CGPoint velocity = [recognizer velocityInView:self.view];
        float magnitude = sqrtf((velocity.x * velocity.x) + (velocity.y * velocity.y));
        float offset = view.x - self.view.width*0.5;
        Debug(@"onPan: %g: %g: %g: %g", view.x, velocity.x, magnitude, offset);
        if ((magnitude > 1500 && ((!right && velocity.x < 0) || (right && velocity.x > 0))) || (!right && offset <= 0) || (right && offset >= 0)) {
            finish(YES);
        } else {
            [UIView animateWithDuration:0.25
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{
                                 view.center = _center;
                             }
                             completion:^(BOOL finished) {
                                 finish(NO);
                             }];
        }
    }
}

- (void)onDrawerPan:(UIPanGestureRecognizer *)recognizer
{
    [self onPan:recognizer view:self.drawerView right:NO finish:^(BOOL finished){ if (finished) [self showPrevious]; }];
}

#pragma mark Pickers

- (void)showImagePickerFromCamera:(id)sender params:(NSDictionary*)params
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) return;
    _picker = [[ImagePicker alloc] initWithView:self];
    _picker.params = params;
    _picker.picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    [self presentViewController:_picker.picker animated:YES completion:NULL];
}

- (void)showImagePickerFromLibrary:(id)sender params:(NSDictionary*)params
{
    _picker = [[ImagePicker alloc] initWithView:self];
    _picker.params = params;
    _picker.picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:_picker.picker animated:YES completion:NULL];
}

- (void)showImagePickerFromAlbums:(NSDictionary*)params
{
    BKImagePickerController *picker = [[BKImagePickerController alloc] init];
    picker.delegate = self;
    [BKui showViewController:self controller:picker name:@"Albums" mode:@"modal" params:params];
}

- (void)onImagePicker:(id)picker image:(UIImage*)image params:(NSDictionary*)params
{
}

- (void)subscribe
{
}

- (void)unsubscribe
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];
}

# pragma mark - UIViewDelegate methods

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return self.barStyle;
}

# pragma mark - UINavigationControllerDelegate methods

- (BKTransitionAnimation*)getAnimation:(BOOL)present
{
    Logger(@"%@: %@", self.name, self.transition);
    if ([self.transition isEmpty:@"type"]) return nil;
    return [[BKTransitionAnimation alloc] init:present mode:self.navigationMode params:self.transition];
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    if (operation == UINavigationControllerOperationNone) return nil;
    BKViewController *view = operation == UINavigationControllerOperationPop && [self.navigationMode isEqual:@"push"] ? (BKViewController*)fromVC : (BKViewController*)toVC;
    return [view getAnimation:operation == UINavigationControllerOperationPush];
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    //navigationController.delegate = nil;
}

- (id <UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController*)navigationController interactionControllerForAnimationController:(id <UIViewControllerAnimatedTransitioning>)animationController
{
    return self.interactionController;
}

# pragma mark - UIViewControllerTansitioningDelegate methods

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    BKViewController *view = (BKViewController*)presented;
    return [view getAnimation:YES];
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    BKViewController *view = (BKViewController*)dismissed;
    return [view getAnimation:NO];
}

# pragma mark - UIGestureRecognizerDelegate methods

-(BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return ![otherGestureRecognizer isKindOfClass:UIPanGestureRecognizer.class];
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return [gestureRecognizer isKindOfClass:UIScreenEdgePanGestureRecognizer.class];
}

#pragma mark UISearchBar delegate

- (BOOL)searchBar:(UISearchBar *)searchBar shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text
{
    return YES;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    self.searchText = searchBar.text;
    [self queueTableSearch];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    self.searchText = searchBar.text;
    [self queueTableSearch];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    if ([searchBar isEqual:self.tableSearchBar]) {
        [searchBar resignFirstResponder];
    }
}

# pragma mark - UITextFieldDelegate methods

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)text
{
    if ([textField isEqual:self.tableSearchField]) {
        self.searchText = [textField.text stringByReplacingCharactersInRange:range withString:text];
        [self queueTableSearch];
    }
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if ([textField isEqual:self.tableSearchField]) {
        self.searchText = nil;
        [self queueTableSearch];
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([textField isEqual:self.tableSearchField]) {
        [textField resignFirstResponder];
    }
    return YES;
}

#pragma mark UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
    SuccessBlock block = objc_getAssociatedObject(textView, @"urlBlock");
    if (block) {
        block(URL.absoluteString);
        return NO;
    }
    return YES;
}

#pragma mark UITabBarDelegate

- (void)onTabBarSelect:(UITabBar *)tabBar item:(UITabBarItem *)item
{
    CATransition *animation = [CATransition animation];
    [animation setType:kCATransitionFade];
    [animation setDuration:0.25];
    [animation setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn]];
    [self.view.window.layer addAnimation:animation forKey:@"fadeTransition"];
}

#pragma mark - Table view data source

- (UITableViewCellStyle)getTableCellStyle:(NSIndexPath*)indexPath
{
    return UITableViewCellStyleDefault;
}

- (void)selectTableRow:(int)index animated:(BOOL)animated
{
    NSIndexPath *path = [NSIndexPath indexPathForRow:index inSection:0];
    [self.tableView selectRowAtIndexPath:path animated:animated scrollPosition:UITableViewScrollPositionNone];
    [self onTableSelect:path selected:YES];
}

- (void)onTableSelect:(NSIndexPath *)indexPath selected:(BOOL)selected
{
}

- (void)onTableCell:(UITableViewCell*)cell indexPath:(NSIndexPath*)indexPath
{
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self onTableSelect:indexPath selected:YES];
    if (self.tableAutoUnselect) [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self onTableSelect:indexPath selected:NO];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.itemsSection ? self.itemsSection.count : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.itemsSection) {
        return [self.itemsSection[section] count];
    }
    return self.tableRows + self.items.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return self.tableView.rowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = self.tableCell ? [tableView dequeueReusableCellWithIdentifier:self.tableCell] : nil;
    if (cell == nil) cell = [[UITableViewCell alloc] initWithStyle:[self getTableCellStyle:indexPath] reuseIdentifier:self.tableCell];
    
    double height = [self tableView:tableView heightForRowAtIndexPath:indexPath];
    cell.frame = CGRectMake(0, 0, MIN(tableView.width, cell.width), height);
    cell.separatorInset = UIEdgeInsetsZero;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) [cell setLayoutMargins:UIEdgeInsetsZero];
    [self onTableCell:cell indexPath:indexPath];
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.tableTransparent) {
        cell.backgroundColor = [UIColor clearColor];
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (self.itemsIndexTitle && section >= 0 && section < self.itemsIndexTitle.count) {
        return [self.itemsIndexTitle objectAtIndex:section];
    }
    if (self.itemsIndex && section >= 0 && section < self.itemsIndex.count) {
        return [self.itemsIndex objectAtIndex:section];
    }
    return @"";
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return self.itemsIndex;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index
{
    return self.itemsIndex ? [self.itemsIndex indexOfObject:title] : 0;
}

@end

#pragma mark Image picker

@implementation ImagePicker

- (id)initWithView:(BKViewController*)view
{
    self = [super init];
    self.picker = [[UIImagePickerController alloc] init];
    self.picker.delegate = self;
    self.view = view;
    return self;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:NO completion:NULL];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self.view onImagePicker:picker image:info[UIImagePickerControllerOriginalImage] params:self.params];
    [picker dismissViewControllerAnimated:NO completion:NULL];
}

@end

@implementation UIView (Frame)

@dynamic x, y, width, height, origin, size;

-(CGFloat)x
{
    return self.frame.origin.x;
}

-(CGFloat)y
{
    return self.frame.origin.y;
}

-(CGFloat)width
{
    return self.frame.size.width;
}

-(CGFloat)height
{
    return self.frame.size.height;
}

-(CGPoint)origin
{
    return CGPointMake(self.x, self.y);
}

-(CGSize)size
{
    return CGSizeMake(self.width, self.height);
}

-(CGFloat)right
{
    return self.frame.origin.x + self.frame.size.width;
}

-(CGFloat)bottom
{
    return self.frame.origin.y + self.frame.size.height;
}

-(CGFloat)centerX
{
    return self.center.x;
}

-(CGFloat)centerY
{
    return self.center.y;
}

-(void)setX:(CGFloat)x
{
    CGRect r = self.frame;
    r.origin.x = x;
    self.frame = r;
}

-(void)setY:(CGFloat)y
{
    CGRect r = self.frame;
    r.origin.y = y;
    self.frame = r;
}

-(void)setWidth:(CGFloat)width
{
    CGRect r = self.frame;
    r.size.width = width;
    self.frame = r;
}

-(void)setHeight:(CGFloat)height
{
    CGRect r = self.frame;
    r.size.height = height;
    self.frame = r;
}

-(void)setOrigin:(CGPoint)origin
{
    CGRect r = self.frame;
    r.origin.x = origin.x;
    r.origin.y = origin.y;
    self.frame = r;
}

-(void)setSize:(CGSize)size
{
    CGRect r = self.frame;
    r.size.width = size.width;
    r.size.height = size.height;
    self.frame = r;
}

-(void)setRight:(CGFloat)right
{
    CGRect r = self.frame;
    r.origin.x = right - r.size.width;
    self.frame = r;
}

-(void)setBottom:(CGFloat)bottom
{
    CGRect r = self.frame;
    r.origin.y = bottom - r.size.height;
    self.frame = r;
}

-(void)setCenterX:(CGFloat)centerX
{
    self.center = CGPointMake(centerX, self.center.y);
}

-(void)setCenterY:(CGFloat)centerY
{
    self.center = CGPointMake(self.center.x, centerY);
}

@end
