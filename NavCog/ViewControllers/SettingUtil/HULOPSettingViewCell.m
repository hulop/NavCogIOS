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
 *  IBM Corporation - initial API and implementation
 *******************************************************************************/

#import "HULOPSettingViewCell.h"

@implementation HULOPSettingViewCell

// TODO
// customize accessibility

- (void) update:(HULOPSetting *)setting
{
    
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    UITapGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    [self addGestureRecognizer:recognizer];
    
    self.setting = setting;
    self.title.text = self.setting.label;

    if (self.slider) {
        self.slider.minimumValue = self.setting.min;
        self.slider.maximumValue = self.setting.max;
        if ([self.setting.currentValue isKindOfClass:[NSNumber class]]) {
            self.slider.value = [(NSNumber*)self.setting.currentValue floatValue];
        }
    }
    if (self.switchView) {
        self.switchView.on = [self.setting boolValue];
    }
    if (self.subtitle) {
        if (self.setting.type == OPTION) {
            self.accessoryType = [self.setting boolValue]?UITableViewCellAccessoryCheckmark:UITableViewCellAccessoryNone;
            self.subtitle.text = nil;
        } else {
            self.subtitle.text = [self.setting stringValue];
        }
    }
    if (self.textInput) {
        self.textInput.secureTextEntry = (setting.type == PASSINPUT);
        self.textInput.text = [self.setting stringValue];
    }
    [self refresh];
}

- (void) tapped:(id)sender
{
    if (self.switchView) {
        [self.switchView setOn:!self.switchView.on animated:YES];
        [self switchChanged:self.switchView];
    }
    if (self.setting.type == OPTION) {
        [self.setting.group checkOption:self.setting];
    }
}

-(NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView
{
    if (self.pickerView) {
        return 1;
    }
    return 0;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return [self.setting numberOfRows];
}

- (void)pickerView:(UIPickerView *)pickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component
{
    [self.setting select:row];
    [self.setting save];
}


- (UIView *)pickerView:(UIPickerView *)pickerView
            viewForRow:(NSInteger)row forComponent:(NSInteger)component reusingView:(UIView *)view {
    UILabel *retval = (id)view;
    if (!retval) {
        retval= [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, [pickerView rowSizeForComponent:component].width, [pickerView rowSizeForComponent:component].height)];
    }
    
    retval.text = [self.setting titleForRow:row];
    if (self.setting.type == UUID_TYPE) {
        retval.font = [UIFont systemFontOfSize:11];
    }
    
    return retval;
}

- (void)awakeFromNib {
    // Initialization code
    if (self.pickerView) {
        self.pickerView.dataSource = self;
        self.pickerView.delegate = self;
        [self refresh];
    }
}

- (void) refresh
{
    [self.pickerView reloadAllComponents];
    if ([self.setting selectedRow] > 0) {
        [self.pickerView selectRow:[self.setting selectedRow] inComponent:0 animated:YES];
    }
    
    if (self.valueLabel) {
        self.valueLabel.text = [NSString stringWithFormat:@"%.2f", [self.setting floatValue]];
    }
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    // Configure the view for the selected state
}

- (IBAction)addItem:(id)sender {
  NSString *title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"New %@",@"HULOPSettingView",@"title for new option"), self.setting.label];
  NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Input %@",@"HULOPSettingView",@"prompt message for new option"), self.setting.label];
  alertView = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel",@"HULOPSettingView",@"cancel") otherButtonTitles:NSLocalizedStringFromTable(@"OK",@"HULOPSettingView",@"ok"), nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alertView show];
}

- (IBAction)removeItem:(id)sender {
  NSString *title = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Delete %@",@"HULOPSettingView",@"title for delete alert"), self.setting.label];
  NSString *message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Are you sure to delete %@？",@"HULOPSettingView",@"confirmation message for delete alert"), self.setting.selectedValue];
    
    if ([self.setting numberOfRows] == 1) {
      message = [NSString stringWithFormat:NSLocalizedStringFromTable(@"Could not delete",@"HULOPSettingView",@"message when it cannot be deleted")];
    } else{
      alertView2 = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:NSLocalizedStringFromTable(@"Cancel",@"HULOPSettingView",@"cancel") otherButtonTitles:NSLocalizedStringFromTable(@"OK",@"HULOPSettingView",@"ok"), nil];
    }

    [alertView2 show];
}


- (void)alertView:(UIAlertView *)_alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    if (buttonIndex == 0) {
        return;
    }
    
    if (_alertView == alertView) {
        NSString *colName = [_alertView textFieldAtIndex:0].text;
        NSObject *add = [self.setting checkValue:colName];
        
        if (add) {
            [self.setting addObject: add];
        }
    } else if (_alertView == alertView2){
        [self.setting removeSelected];
    }
    [self refresh];
    [self.setting save];
}

- (IBAction)switchChanged:(id)sender {
    self.setting.currentValue = [NSNumber numberWithBool:((UISwitch*) sender).on];
    [self.setting save];
}

- (IBAction)valueChanged:(id)sender {
    if (sender == self.slider) {
        self.setting.currentValue = [self.setting checkValue:[NSNumber numberWithDouble:((UISlider*)sender).value]];
    }
    if (sender == self.textInput) {
        self.setting.currentValue = self.textInput.text;
    }
    [self refresh];
    [self.setting save];
}

@end
