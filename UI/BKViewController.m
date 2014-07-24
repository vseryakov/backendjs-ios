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
- (id)initWithView:(BKViewController*)view;
@end;

@interface BKViewController () <UIViewControllerTransitioningDelegate,UINavigationControllerDelegate,
                                UIGestureRecognizerDelegate,UITableViewDelegate,UITableViewDataSource,
                                UITextFieldDelegate,UITextViewDelegate,UISearchBarDelegate,
                                UIActionSheetDelegate>
@end

@implementation BKViewController {
    int _activityCount;
    CGPoint _center;
    UIView *_contentView;
    CGRect _drawerFrame;
    BOOL _panStarted;
    NSTimer *_timer;
    ImagePicker *_picker;
}

- (instancetype)init
{
    self = [super init];
    _activityCount = 0;
    self.params = [@{} mutableCopy];
    self.itemsAll = nil;
    self.items = [@[] mutableCopy];
    self.menubarItems = [@[] mutableCopy];
    self.transitionVelocity = 1;
    self.transitionDamping = 1;
    self.transitionDuration = 0.5;
    self.transitionOptions = 0;
    self.menubarButtons = [@{} mutableCopy];
    self.barStyle = UIStatusBarStyleDefault;
    self.toolbarOffset = 10;
    self.toolbarBackTitle = @"Back";
    self.toolbarNextTitle = @"Next";
    self.tableSections = 1;
    self.tableRows = 0;
    self.tableCell = nil;
    self.tableRestore = NO;
    self.tableUnselected = NO;
    self.tableRounded = NO;
    self.tableSearchable = NO;
    self.tableSearchHidden = YES;
    self.tableRefreshable = NO;
    self.drawerPanning = YES;
    self.panInPushMode = YES;
    self.panRect = CGRectZero;
    self.transitioningDelegate = self;
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

    self.view.backgroundColor = [UIColor whiteColor];

    self.automaticallyAdjustsScrollViewInsets = NO;
    self.navigationController.navigationBarHidden = YES;
    self.extendedLayoutIncludesOpaqueBars = YES;
    [self setNeedsStatusBarAppearanceUpdate];
    [self subscribe];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;

    // Replace button fonts manually
    for (UIButton *view in self.view.subviews) {
        if ([view isKindOfClass:[UIButton class]]) {
            view.titleLabel.font = [UIFont systemFontOfSize:view.titleLabel.font.pointSize];
        }
    }
    // Do not preserve selection
    if (self.tableView && self.tableUnselected) {
        [self onTableSelect:[self.tableView indexPathForSelectedRow] selected:NO];
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:NO];
    }
    if (self.tableSearchHidden && self.tableSearchable) {
        self.tableView.contentOffset = CGPointMake(0, self.tableView.tableHeaderView.height);
    }
    self.activityView.center = self.view.center;
    [self.emptyView removeFromSuperview];
    [self getItems];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.activityView.center = self.view.center;
    [self.view bringSubviewToFront:self.activityView];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self saveTablePosition:nil];
    self.navigationController.navigationBarHidden = YES;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:nil object:nil];
}

- (void)addEmptyView:(NSString*)text
{
    self.emptyView = [[UIView alloc] initWithFrame:CGRectMake(0, 64, self.view.width, self.view.height - 64)];
    self.emptyView.backgroundColor = self.view.backgroundColor;
    
    self.emptyTextView = [[UITextView alloc] initWithFrame:self.emptyView.bounds];
    [self.emptyView addSubview:self.emptyTextView];
    self.emptyTextView.textColor = [UIColor grayColor];
    self.emptyTextView.userInteractionEnabled = YES;
    self.emptyTextView.selectable = YES;
    self.emptyTextView.editable = NO;
    self.emptyTextView.delegate = self;
    self.emptyTextView.textContainerInset = UIEdgeInsetsMake(20, 10, 20, 10);
    self.emptyTextView.textAlignment = NSTextAlignmentCenter;
    if (!text) return;
    self.emptyTextView.text = text;
    [self.emptyTextView sizeToFit];
    self.emptyTextView.y = self.emptyView.height/2 - self.emptyTextView.height/2;
}

- (void)addEmptyView:(NSString*)text links:(NSArray*)links handler:(SuccessBlock)handler
{
    [self addEmptyView:nil];
    [BKui setTextLinks:self.emptyTextView text:text links:links handler:handler];
    [self.emptyTextView sizeToFit];
    self.emptyTextView.y = self.emptyView.height/2 - self.emptyTextView.height/2;
}

- (void)addToolbar:(NSString*)title
{
    self.toolbarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 64)];
    self.toolbarView.userInteractionEnabled = YES;
    self.toolbarView.backgroundColor = self.view.backgroundColor;
    [self.view addSubview:self.toolbarView];
    
    [BKui setViewShadow:self.toolbarView color:nil offset:0.5 opacity:0.5];
    
    self.toolbarBack = [BKui makeCustomButton];
    [self setToolbarBackButton:self.toolbarBackTitle image:[UIImage imageNamed:self.toolbarBackIcon]];
    [self.toolbarBack addTarget:self action:@selector(onBack:) forControlEvents:UIControlEventTouchUpInside];
    [self.toolbarView addSubview:self.toolbarBack];
    
    self.toolbarTitle = [[UILabel alloc] initWithFrame:CGRectMake(0, 20, self.toolbarView.width, self.toolbarView.height-20)];
    self.toolbarTitle.textAlignment = NSTextAlignmentCenter;
    self.toolbarTitle.text = title;
    [self.toolbarView addSubview:self.toolbarTitle];
    
    self.toolbarNext = [BKui makeCustomButton];
    self.toolbarNext.hidden = YES;
    [self setToolbarNextButton:self.toolbarNextTitle image:[UIImage imageNamed:self.toolbarNextIcon]];
    [self.toolbarNext addTarget:self action:@selector(onNext:) forControlEvents:UIControlEventTouchUpInside];
    [self.toolbarView addSubview:self.toolbarNext];
}

- (void)setToolbarBackButton:(NSString*)title image:(UIImage*)image
{
    if (self.toolbarBack) {
        if (self.toolbarBackIcon) {
            [self.toolbarBack setImage:image forState:UIControlStateNormal];
        } else {
            [self.toolbarBack setTitle:title forState:UIControlStateNormal];
        }
        [self.toolbarBack sizeToFit];
        self.toolbarBack.center = CGPointMake(self.toolbarBack.width/2 + self.toolbarOffset, self.toolbarView.height/2 + self.toolbarOffset);
        
    }
}

- (void)setToolbarNextButton:(NSString*)title image:(UIImage*)image
{
    if (self.toolbarNext) {
        if (self.toolbarNextIcon) {
            [self.toolbarNext setImage:image forState:UIControlStateNormal];
        } else {
            [self.toolbarNext setTitle:title forState:UIControlStateNormal];
        }
        [self.toolbarNext sizeToFit];
        self.toolbarNext.center = CGPointMake(self.toolbarView.width-self.toolbarNext.width/2 - self.toolbarOffset, self.toolbarView.height/2 + self.toolbarOffset);
    }
}

#pragma mark Menubar

- (void)addMenubar:(NSArray*)items params:(NSDictionary*)params
{
    if (!items) return;
    self.menubarItems = [@[] mutableCopy];
    self.menubarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 64)];
    self.menubarView.userInteractionEnabled = YES;
    self.menubarView.backgroundColor = self.view.backgroundColor;
    [self.view addSubview:self.menubarView];
    [BKui setViewShadow:self.menubarView color:nil offset:0.5 opacity:0.5];

    int i = 0, w = self.view.width / items.count;
    
    for (NSDictionary *obj in items) {
        NSString *name = obj[@"name"];
        if (!name) continue;
        
        NSMutableDictionary *item = [obj mutableCopy];
        [self.menubarItems addObject:item];
        
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.frame = CGRectMake(i * w, 20, w, 44);
        button.exclusiveTouch = YES;
        [button addTarget:self action:@selector(onMenubar:) forControlEvents:UIControlEventTouchUpInside];
        button.imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        if (item[@"x-inset"] || item[@"y-inset"]) {
            button.frame = CGRectInset(button.frame, [item num:@"x-inset"], [item num:@"y-inset"]);
        }
        if (item[@"disabled"]) {
            button.enabled = NO;
        }
        if (item[@"icon"]) {
            UIImage *image = [UIImage imageNamed:item[@"icon"]];
            [button setImage:image forState:UIControlStateNormal];
            if (item[@"icon-active"]) [button setImage:[UIImage imageNamed:item[@"icon-active"]] forState:UIControlStateHighlighted];
            if (item[@"icon-disabled"]) [button setImage:[UIImage imageNamed:item[@"icon-disabled"]] forState:UIControlStateDisabled];
        } else {
            [button setTitle:item[@"name"] forState:UIControlStateNormal];
            if (item[@"name-active"]) [button setTitle:item[@"name-active"] forState:UIControlStateHighlighted];
            if (item[@"name-disabled"]) [button setTitle:item[@"name-disabled"] forState:UIControlStateDisabled];
            if (item[@"color"]) [button setTitleColor:item[@"color"] forState:UIControlStateNormal];
            if (item[@"color-active"]) [button setTitleColor:item[@"color-active"] forState:UIControlStateHighlighted];
            if (item[@"color-disabled"]) [button setTitleColor:item[@"color-disabled"] forState:UIControlStateDisabled];
            if (item[@"font"]) [button.titleLabel setFont:item[@"font"]];
        }
        [self.menubarView addSubview:button];
        
        // Configure the menubar
        if (params) {
            if ([name isEqual:params[@"current"]]) {
                button.tag = 999;
            }
            for (NSString *d in params[@"menubar-disabled"]) {
                if ([name isEqual:d]) button.enabled = NO;
            }
        }
        _menubarButtons[name] = button;
        i++;
    }
   
    self.navigationController.navigationBarHidden = YES;
}

- (void)setMenubarButton:(NSString*)name enabled:(BOOL)enabled
{
    UIButton *button = self.menubarButtons[name];
    if (!button) return;
    button.enabled = enabled;
}

- (void)updateMenubar
{
    for (NSString *name in self.menubarButtons) {
        UIButton *button = self.menubarButtons[name];
        button.highlighted = button.tag == 999 ? YES :NO;
    }
}

- (IBAction)onMenubar:(id)sender
{
    for (NSString *name in self.menubarButtons) {
        UIButton *button = self.menubarButtons[name];
        if (sender == button) {
            // Find additional parameters for given action
            NSDictionary *action = @{};
            for (NSDictionary *item in self.menubarItems) {
                if ([name isEqual:item[@"name"]]) {
                    action = item;
                    break;
                }
            }
            if (action[@"selector"]) {
                [BKjs invoke:self name:action[@"selector"] arg:nil];
            } else {
                // Replace active button with normal icon to keep tool bar state for drawers
                if ([BKjs matchString:@"drawer" string:action[@"view"]]) {
                    button.highlighted = NO;
                }
                [BKui showViewController:self name:action[@"view"] ? action[@"view"] : name params:action[@"params"]];
            }
            break;
        }
    }
}

#pragma mark Table

- (void)addTable
{
    CGRect frame = CGRectMake(0, 64, self.view.width, self.view.height - 64);
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

    if (self.tableRounded) {
        self.tableView.backgroundColor = [UIColor clearColor];
    }
    
    if (!self.tableSearchNames) {
        self.tableSearchNames = @[@"name", @"alias", @"email"];
    }
    self.tableSearch = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, 44)];
    self.tableSearch.placeholder = @"Search";
    self.tableSearch.delegate = self;
    if (self.tableSearchable) {
        self.tableView.tableHeaderView = self.tableSearch;
    }
    
    self.tableRefresh = [[UIRefreshControl alloc]init];
    [self.tableRefresh addTarget:self action:@selector(refreshItems) forControlEvents:UIControlEventValueChanged];
    if (self.tableRefreshable) {
        [self.tableView addSubview:self.tableRefresh];
    }
    [self.view addSubview:self.tableView];
}

- (void)reloadTable
{
    if ([self.itemsAll isKindOfClass:[NSArray class]] && ![self.itemsAll isEqual:self.items]) {
        self.items = [self filterItems:self.itemsAll];
    }
    Logger(@"items: %d", self.items.count);
    
    if (self.tableRefresh.isRefreshing) [self.tableRefresh endRefreshing];
    [self.tableView reloadData];
}

- (void)getItems
{
}

- (void)refreshItems
{
    [self getItems];
}

- (id)getItem:(NSIndexPath*)indexPath
{
    NSInteger index = indexPath.row - self.tableRows;
    return index >= 0 && index < [self.items count] ? self.items[index] : nil;
}

- (void)setItem:(NSIndexPath*)indexPath data:(id)data
{
    NSInteger index = indexPath.row - self.tableRows;
    if (index >= 0 && index < [self.items count]) self.items[index] = data;
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
    if (_timer) [_timer invalidate];
    _timer = [NSTimer timerWithTimeInterval:0.4 target:self selector:@selector(onTableSearch:) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:_timer forMode:NSRunLoopCommonModes];
}

- (NSMutableArray*)filterItems:(NSArray*)items
{
    NSMutableArray *list = [@[] mutableCopy];
    if (![items isKindOfClass:[NSArray class]]) return list;
    
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
    return list;
}

- (void)onTableSearch:(id)sender
{
    Debug(@"%@, %d items", self.searchText, self.items.count);
    
    // Clearing the text while the spell suggestion is up may clear but never calls the delegate
    if (![self.searchText isEqual:self.tableSearch.text]) self.tableSearch.text = self.searchText;
    
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
    if (self.toolbarNextController) {
        [BKui showViewController:self name:self.toolbarNextController params:self.params];
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
    Logger(@"showPrevious: %@: %@ %@", self.name, self.navigationMode, self.previousName);
    
    if ([self.navigationMode hasPrefix:@"drawer"]) {
        [self prepareForHide:params];
        [self hideDrawer];
        return;
    }
    
    if ([self.navigationMode isEqual:@"push"]) {
        [self prepareForHide:params];
        [self.navigationController popViewControllerAnimated:YES];
        return;
    }

    if ([self.navigationMode isEqual:@"modal"]) {
        [self prepareForHide:params];
        [self dismissViewControllerAnimated:YES completion:nil];
        return;
    }

    // Replace with previous controller completely
    [BKui showViewController:self name:self.previousName params:params];
}

- (void)showDrawer:(UIViewController*)owner
{
    CGRect frame = self.view.frame;
    
    // Screen capture the current content of the navigation view (alogn with the navigation bar, if any)
    UIImage *image = [BKui captureImage:owner.view.window];
    
    // Sliding button with the screenshot
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
    if (self.drawerPanning == YES) {
        self.drawerPanGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onDrawerPan:)];
        self.drawerPanGesture.delegate = self;
        [self.view addGestureRecognizer:self.drawerPanGesture];
    }
    
    [owner.navigationController pushViewController:self animated:NO];
    
    BKBounceAnimation *bounce = [[BKBounceAnimation alloc] initWithKeyPath:@"position.x" start:nil stop:nil];
    bounce.fromValue = [NSNumber numberWithFloat:self.drawerView.center.x];
    bounce.toValue = [NSNumber numberWithFloat:_drawerFrame.origin.x + _drawerFrame.size.width/2];
    [bounce configure:self.drawerView];
}

- (void)hideDrawer
{
    if (![self.drawerView isKindOfClass:[UIView class]]) return;
    
    BKBounceAnimation *bounce = [[BKBounceAnimation alloc] initWithKeyPath:@"position.x" start:nil stop:^(id anim) {
        [self.navigationController popViewControllerAnimated:NO];
        [self.drawerView removeFromSuperview];
        self.drawerView = nil;
    }];
    bounce.fromValue = [NSNumber numberWithFloat:self.drawerView.center.x];
    bounce.toValue = [NSNumber numberWithFloat:self.view.center.x];
    bounce.overshoot = NO;
    [bounce configure:self.drawerView];
}

- (void)prepareForShow:(UIViewController*)owner name:(NSString*)name mode:(NSString*)mode params:(NSDictionary*)params
{
    self.name = name;
    self.navigationMode = mode ? mode : @"";
    self.previousName = [owner isKindOfClass:[BKViewController class]] ? [(BKViewController*)owner name] : @"";
    [self.params removeAllObjects];
    for (id key in params) self.params[key] = params[key];
    
    if ([self.navigationMode isEqual:@"push"]) {
        self.navigationController.delegate = self;
        owner.navigationController.delegate = self;
        
        if (self.panInPushMode) {
            _contentView = self.view;
            UIImageView *bg = [[UIImageView alloc] initWithFrame:owner.view.frame];
            bg.image = [BKui captureImage:owner.view.window];
            bg.userInteractionEnabled = YES;
            self.view = bg;
            [self.view addSubview:_contentView];
            
            self.panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(onPushPan:)];
            self.panGesture.delegate = self;
            [self.view addGestureRecognizer:self.panGesture];
        }
    }
    
    if ([self.navigationMode isEqual:@"modal"]) {
        self.transitioningDelegate = self;
        self.modalPresentationStyle = UIModalPresentationCustom;
    }
    
    if ([self.navigationMode isEqual:@""]) {
        owner.navigationController.delegate = self;
        self.navigationController.delegate = self;
    }
}

- (void)prepareForHide:(NSDictionary*)params
{
    if ([[self prevController] isKindOfClass:[BKViewController class]]) {
        BKViewController *prev = (BKViewController*)[self prevController];
        for (id key in params) prev.params[key] = params[key];
        [prev updateMenubar];
    }
}

- (void)onPan:(UIPanGestureRecognizer *)recognizer view:(UIView*)view right:(BOOL)right completion:(GenericBlock)completion
{
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint point = [recognizer locationInView:self.view];
        if (CGRectEqualToRect(self.panRect, CGRectZero) || CGRectContainsPoint(self.panRect, point)) {
            _center = view.center;
            _panStarted = YES;
        }
    } else
    if (_panStarted && recognizer.state == UIGestureRecognizerStateChanged) {
        CGPoint point = [recognizer translationInView:self.view];
        if (_center.x + point.x >= self.view.frame.size.width/2) {
            view.center = CGPointMake(_center.x + point.x, _center.y);
        }
    } else
    if (_panStarted && (recognizer.state == UIGestureRecognizerStateEnded || recognizer.state == UIGestureRecognizerStateCancelled || recognizer.state == UIGestureRecognizerStateFailed)) {
        _panStarted = NO;
        CGPoint velocity = [recognizer velocityInView:self.view];
        float magnitude = sqrtf((velocity.x * velocity.x) + (velocity.y * velocity.y));
        float offset = view.frame.origin.x - self.view.frame.size.width*0.5;
        Debug(@"onPan: %g: %g: %g: %g", view.frame.origin.x, velocity.x, magnitude, offset);
        if ((magnitude > 1500 && ((!right && velocity.x < 0) || (right && velocity.x > 0))) || (!right && offset <= 0) || (right && offset >= 0)) {
            completion();
        } else {
            [UIView animateWithDuration:0.25
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut
                             animations:^{ view.center = _center; }
                             completion:nil];
        }
    }
}

- (void)onDrawerPan:(UIPanGestureRecognizer *)recognizer
{
    [self onPan:recognizer view:self.drawerView right:NO completion:^{ [self showPrevious]; }];
}

- (void)onPushPan:(UIPanGestureRecognizer *)recognizer
{
    [self onPan:recognizer view:_contentView right:YES completion:^{
            [UIView animateWithDuration:0.25
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseOut|UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionOverrideInheritedDuration
                             animations:^{
                                 _contentView.center = CGPointMake(self.view.frame.size.width*1.5, self.view.center.y);
                             } completion:^(BOOL stop) {
                                 [self.navigationController popViewControllerAnimated:NO];
                                 self.view = _contentView;
                                 _contentView = nil;
                             }];
    }];
}

#pragma mark Pickers

- (void)showImagePickerFromCamera:(id)sender
{
    if (![UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) return;
    _picker = [[ImagePicker alloc] initWithView:self];
    _picker.picker.sourceType = UIImagePickerControllerSourceTypeCamera;
    [self presentViewController:_picker.picker animated:YES completion:NULL];
}

- (void)showImagePickerFromLibrary:(id)sender
{
    _picker = [[ImagePicker alloc] initWithView:self];
    _picker.picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    [self presentViewController:_picker.picker animated:YES completion:NULL];
}

- (void)showImagePickerFromAlbums:(NSDictionary*)params
{
    NSMutableDictionary *aparams = [@{} mutableCopy];
    for (id key in params) aparams[key] = params[key];
    aparams[@"_block"] = ^(NSDictionary *item) {
        // Keep reference when calling a callback so the image will not be freed
        UIImage *img = item[@"_image"];
        [self onImagePicker:img];
    };
    BKImagePickerController *picker = [[BKImagePickerController alloc] init];
    [BKui showViewController:self controller:picker name:@"Albums" mode:@"push" params:params];
}

- (void)onImagePicker:(UIImage*)image
{
}

- (void)subscribe
{
}

# pragma mark - UIViewDelegate methods

- (UIStatusBarStyle)preferredStatusBarStyle
{
    return self.barStyle;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.view endEditing:YES];
    [super touchesBegan:touches withEvent:event];
}

# pragma mark - UINavigationControllerDelegate methods

- (BKTransitionAnimation*)getAnimation:(BOOL)present
{
    if (!self.transitionType) return nil;
    BKTransitionAnimation *anim = [[BKTransitionAnimation alloc] init:present type:self.transitionType duration:self.transitionDuration];
    anim.velocity = self.transitionVelocity;
    anim.damping = self.transitionDamping;
    anim.options = self.transitionOptions;
    return anim;
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    if (operation == UINavigationControllerOperationNone) return nil;
    BKViewController *view = operation == UINavigationControllerOperationPush ? (BKViewController*)toVC : (BKViewController*)fromVC;
    if (view.transitionType) return [view getAnimation:operation == UINavigationControllerOperationPush];
    return nil;
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    navigationController.delegate = nil;
}

# pragma mark - UIViewControllerTansitioningDelegate methods

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForPresentedController:(UIViewController *)presented presentingController:(UIViewController *)presenting sourceController:(UIViewController *)source
{
    BKViewController *view = (BKViewController*)presented;
    if (view.transitionType) return [view getAnimation:YES];
    return nil;
}

- (id<UIViewControllerAnimatedTransitioning>)animationControllerForDismissedController:(UIViewController *)dismissed
{
    BKViewController *view = (BKViewController*)dismissed;
    if (view.transitionType) return [view getAnimation:NO];
    return nil;
}

# pragma mark - UIGestureRecognizerDelegate methods

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch
{
    if (recognizer == self.panGesture) {
        if ([touch.view isKindOfClass:[BKRangeSlider class]] || [touch.view isKindOfClass:[UISlider class]]) return NO;
    }
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)recognizer
{
    if (recognizer == self.panGesture) {
        CGPoint point = [recognizer locationInView:self.view];
        if (!CGRectEqualToRect(self.panRect, CGRectZero) && !CGRectContainsPoint(self.panRect, point)) return NO;
    }
    return YES;
}

#pragma  mark UISearchBar delegate

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
    if ([searchBar isEqual:self.tableSearch]) {
        [searchBar resignFirstResponder];
    }
}

# pragma mark - UITextFieldDelegate methods

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)text
{
    if ([textField isEqual:self.tableSearch]) {
        self.searchText = [textField.text stringByReplacingCharactersInRange:range withString:text];
        [self queueTableSearch];
    }
    return YES;
}

- (BOOL)textFieldShouldClear:(UITextField *)textField
{
    if ([textField isEqual:self.tableSearch]) {
        self.searchText = nil;
        [self queueTableSearch];
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if ([textField isEqual:self.tableSearch]) {
        [textField resignFirstResponder];
    }
    return YES;
}

#pragma mark UITextViewDelegate

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange
{
    SuccessBlock block = objc_getAssociatedObject(textView, @"actionBlock");
    if (block) {
        block(URL.absoluteString);
        return NO;
    }
    return YES;
}

#pragma mark UIScrollView delegate

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self.tableSearch resignFirstResponder];
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
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self onTableSelect:indexPath selected:NO];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.tableSections;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.tableRows + self.items.count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return tableView.rowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = self.tableCell ? [tableView dequeueReusableCellWithIdentifier:self.tableCell] : nil;
    if (cell == nil) cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:self.tableCell];
    
    double height = [self tableView:tableView heightForRowAtIndexPath:indexPath];
    cell.frame = CGRectMake(0, 0, MIN(tableView.width, cell.width), height);
    cell.accessoryType = UITableViewCellAccessoryNone;
    
    // Rounded table, round corners on the first and last cells
    if (self.tableRounded) {
        if (indexPath.row == 0) {
            [BKui setRoundCorner:cell corner:UIRectCornerTopLeft|UIRectCornerTopRight radius:0];
        }
        if (indexPath.row == [self tableView:tableView numberOfRowsInSection:indexPath.section] - 1) {
            [BKui setRoundCorner:cell corner:UIRectCornerBottomLeft|UIRectCornerBottomRight radius:0];
        }
    }
    [self onTableCell:cell indexPath:indexPath];
    return cell;
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
    [self.view onImagePicker:info[UIImagePickerControllerOriginalImage]];
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
    CGRect r        = self.frame;
    r.origin.x      = x;
    self.frame      = r;
}

-(void)setY:(CGFloat)y
{
    CGRect r        = self.frame;
    r.origin.y      = y;
    self.frame      = r;
}

-(void)setWidth:(CGFloat)width
{
    CGRect r        = self.frame;
    r.size.width    = width;
    self.frame      = r;
}

-(void)setHeight:(CGFloat)height
{
    CGRect r        = self.frame;
    r.size.height   = height;
    self.frame      = r;
}

-(void)setOrigin:(CGPoint)origin
{
    self.x          = origin.x;
    self.y          = origin.y;
}

-(void)setSize:(CGSize)size
{
    self.width      = size.width;
    self.height     = size.height;
}

-(void)setRight:(CGFloat)right
{
    CGRect frame = self.frame;
    frame.origin.x = right - frame.size.width;
    self.frame = frame;
}

-(void)setBottom:(CGFloat)bottom
{
    CGRect frame = self.frame;
    frame.origin.y = bottom - frame.size.height;
    self.frame = frame;
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
