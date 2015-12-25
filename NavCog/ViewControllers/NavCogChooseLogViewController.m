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
 *  Dragan Ahmetovic (CMU) - initial API and implementation
 *  IBM Corporation - initial API and implementation
 *******************************************************************************/

#import "NavCogChooseLogViewController.h"

@interface NavCogChooseLogViewController ()

@property (strong, nonatomic) NSMutableArray *logFileNameList;
@property (weak, nonatomic) IBOutlet UITableView *logFileNameListTableView;

@end

@implementation NavCogChooseLogViewController

- (NSMutableArray *)loadLogList {
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString* documentsPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
    NSArray* allFileNames = [fm contentsOfDirectoryAtPath:documentsPath error:nil];
    NSMutableArray* logList = [[NSMutableArray alloc] init];
    
    for (NSString* fileName in allFileNames) {
        if([[fileName lowercaseString] hasSuffix:@".log"]) {
            NSMutableDictionary *obj = [@{@"fileName":fileName, @"dir":documentsPath} mutableCopy];
            [logList addObject: obj];
            [self checkLog:obj];
            
        }
    }
    
    return logList;
}

- (void) checkLog:(NSMutableDictionary*) obj
{
    NSString *filePath = [obj[@"dir"] stringByAppendingPathComponent:obj[@"fileName"]];
    
    FILE *fp = fopen([filePath UTF8String], "r");
    char buff[4096];
    long count = 0;
    char start[256];
    char end[256];
    
    while(fgets(buff, 4096, fp) != NULL) {
        if (strlen(buff) == 0) {
            break;
        }
        else if (strlen(buff) < 23) {
            break;
        }
        else if (strstr(buff, "]") == NULL) {
            break;
        }
        else if (strstr(buff, "Route") != NULL) {
            sscanf(strstr(buff, "Route"), "Route,%[^','],%[^'\n']\n", start, end);
        }
        count++;
    }
    fclose(fp);

    obj[@"count"] = @(count);
    obj[@"start"] = [NSString stringWithCString:start encoding:NSUTF8StringEncoding];
    obj[@"end"] = [NSString stringWithCString:end encoding:NSUTF8StringEncoding];
}

+ (instancetype)sharedLogChooser {
    static NavCogChooseLogViewController *instance = nil;
    if (instance == nil) {
        instance = [[NavCogChooseLogViewController alloc] init];
        instance.logFileNameList = [[NSMutableArray alloc] init];
    }

    NSArray *list = [instance loadLogList];
    [instance.logFileNameList removeAllObjects];
    for(NSDictionary *log in list) {
        if (log[@"invalid"]) {
            continue;
        }
        [instance.logFileNameList addObject:log];
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [instance.logFileNameListTableView reloadData];
    });

    return instance;
}

+ (void)setLogChooserDelegate:(id)obj {
    NavCogChooseLogViewController *instance = [NavCogChooseLogViewController sharedLogChooser];
    instance.delegate = obj;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.view.frame = [UIScreen mainScreen].bounds;
    self.view.bounds = [UIScreen mainScreen].bounds;
    _logFileNameListTableView.delegate = self;
    _logFileNameListTableView.dataSource = self;
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

- (IBAction)backToNavUIView:(id)sender {
    [self.view removeFromSuperview];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_logFileNameList count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *simpleTableIdentifier = @"logListTableItems";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:simpleTableIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:simpleTableIdentifier];
    }
    NSDictionary *obj = _logFileNameList[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ -> %@ - %@", obj[@"start"], obj[@"end"], obj[@"count"]];
    cell.detailTextLabel.text = obj[@"fileName"];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *obj = _logFileNameList[indexPath.row];
    NSString *logName = obj[@"fileName"];

    [_delegate logToSimulate:logName];
}

@end
