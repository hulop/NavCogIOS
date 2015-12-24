/*******************************************************************************
 * Copyright (c) 2014, 2015  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Contributors:
 *  Chengxiong Ruan (CMU) - initial API and implementation
 *******************************************************************************/

#import "NavCogChooseMapViewController.h"
#import "NavDownloadingViewController.h"

@interface NavCogChooseMapViewController ()

@property (strong, nonatomic) NSMutableArray *mapNameList;
@property (weak, nonatomic) IBOutlet UITableView *mapListTableView;
@property (strong, nonatomic) NavDownloadingViewController *downloadingView;

@end

@implementation NavCogChooseMapViewController

+ (instancetype)sharedMapChooser {
    static NavCogChooseMapViewController *instance = nil;
    if (instance == nil) {
        instance = [[NavCogChooseMapViewController alloc] init];
        instance.mapNameList = [[NSMutableArray alloc] init];
        instance.downloadingView = [[NavDownloadingViewController alloc] init];
        [NavMapManager setMapManagerDelegate:instance];
        NSArray *mapList = [NavMapManager getMapNameList];
        for (NSString *mapName in mapList) {
            [instance.mapNameList addObject:mapName];
        }
    }
    return instance;
}

+ (void)setMapChooserDelegate:(id)obj {
    NavCogChooseMapViewController *instance = [NavCogChooseMapViewController sharedMapChooser];
    instance.delegate = obj;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.bounds = [UIScreen mainScreen].bounds;
    _mapListTableView.delegate = self;
    _mapListTableView.dataSource = self;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

- (IBAction)updateMapList:(id)sender {
    [self.view addSubview:_downloadingView.view];
    _downloadingView.label.text = NSLocalizedString(@"downloadingMapList", @"Label shown when map list is downloading");
    _downloadingView.progress.hidden = YES;
    [NavMapManager updateMapList];
}

- (IBAction)backToNavUIView:(id)sender {
    [self.view removeFromSuperview];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_mapNameList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *simpleTableIdentifier = @"navMapListTableItems";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:simpleTableIdentifier];
    }
    cell.textLabel.text = [_mapNameList objectAtIndex:indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    NSString *mapName = cell.textLabel.text;
    [self.view addSubview:_downloadingView.view];
    _downloadingView.label.text = NSLocalizedString(@"loadingMap", @"Indicator text shown while a map is loading");
    _downloadingView.progress.hidden = YES;
    _downloadingView.progress.progress = 0;
    [NavMapManager loadTopoMapWithName:mapName withProgressHandler:^(long long current, long long max) {
        dispatch_async(dispatch_get_main_queue(), ^{
            long size = [[[[NavMapManager getMapDict] objectForKey:mapName] objectForKey:@"size"] longValue];
            _downloadingView.progress.progress = ((float)current)/size;
            _downloadingView.progress.hidden = NO;
            
            if (_downloadingView.progress.progress < 1.0) {
                _downloadingView.label.text = [NSString stringWithFormat:NSLocalizedString(@"mapProgressFormat", @"Format string for map downloading progress indicator"), _downloadingView.progress.progress*100];
            } else {
                _downloadingView.label.text = NSLocalizedString(@"processingMap", @"Indication text shown while a map is being processed");
            }
        });
    }];
}

- (void)mapListUpdated:(NSArray *)mapList withError:(NSError *)error {
    [_mapNameList removeAllObjects];
    if (mapList) {
        for (NSString *mapName in mapList) {
            [_mapNameList addObject:mapName];
        }
    }
    
    // need to update from main queue
    dispatch_async(dispatch_get_main_queue(), ^{
        [_downloadingView.view removeFromSuperview];
        [_mapListTableView reloadData];
    });
}

- (void)topoMapLoaded:(TopoMap *)topoMap withMapDataString:(NSString *)dataStr withError:(NSError *)error {

    // need to update from main queue
    dispatch_async(dispatch_get_main_queue(), ^{
        if (error != nil) {
            [self.view removeFromSuperview];
            return;
        }
        [_downloadingView.view removeFromSuperview];
        [self.view removeFromSuperview];
    });
    [_delegate topoMapLoaded:topoMap withMapDataString:dataStr];
}



@end
