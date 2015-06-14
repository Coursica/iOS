//
//  DetailViewController.m
//  Coursica
//
//  Created by Matthew Beatty on 11/25/14.
//  Copyright (c) 2014 Prestige Worldwide. All rights reserved.
//

#import "DetailViewController.h"
#import "Course.h"
#import "AppDelegate.h"
#import "Faculty.h"
#import "Location.h"
#import "Meeting.h"
#import "GraphKit.h"
#import "QScore.h"
#import "CommentsViewController.h"
#import "UILabel+HeightCalculation.h"
#import "QReport.h"
#import <Firebase/Firebase.h>
#import "NSString+FirebaseEncode.h"
#import "QFacultyReport.h"
#import "Mantle.h"
#import "QResponse.h"
#import "Meeting.h"

#define CoursicaBlue [UIColor colorWithRed:31/255.0 green:148/255.0 blue:255/255.0 alpha:1.0]
#define UnselectedGray [UIColor colorWithRed:217/255.0 green:215/255.0 blue:215/255.0 alpha:1.0]

@interface DetailViewController () <GKBarGraphDataSource>

@property (nonatomic, strong) IBOutletCollection(UIView) NSArray *cards;
@property (weak, nonatomic) IBOutlet UIView *infoView;
@property (weak, nonatomic) IBOutlet UIView *QScoreView;

@property (weak, nonatomic) IBOutlet UIScrollView *scrollView;
@property (weak, nonatomic) IBOutlet UIView *contentView;

// References to the UI elements used in the controller's view
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *descriptionLabel;

@property (weak, nonatomic) IBOutlet UILabel *courseInstructorLabel;
@property (weak, nonatomic) IBOutlet UILabel *courseMeetingLabel;
@property (weak, nonatomic) IBOutlet UILabel *courseLocationLabel;
@property (weak, nonatomic) IBOutlet UILabel *courseInfoLabel;
@property (weak, nonatomic) IBOutlet UILabel *satisfiesLabel;

@property (weak, nonatomic) IBOutlet UILabel *overallLabel;
@property (weak, nonatomic) IBOutlet UILabel *difficultyLabel;
@property (weak, nonatomic) IBOutlet UILabel *workloadLabel;

@property (strong, nonatomic) QScore *overallScore;
@property (strong, nonatomic) QScore *difficultyScore;
@property (strong, nonatomic) QScore *workloadScore;

@property (nonatomic, strong) IBOutletCollection(UIButton) NSArray *qScoreButtons;
@property (nonatomic, strong) IBOutletCollection(UILabel) NSArray *qScoreLabels;
@property (assign) NSInteger selectedQScoreIndex;

@property (weak, nonatomic) IBOutlet UIButton *viewCommentsButton;

@property (weak, nonatomic) IBOutlet UISegmentedControl *graphControl;
@property (nonatomic, weak) IBOutlet GKBarGraph *graphView;
@property (nonatomic, assign) BOOL green;

@property (strong, nonatomic) QReport *report;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *descriptionHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *notesHeightConstraint;

@end

@implementation DetailViewController

- (void)viewDidLoad {
    
    [super viewDidLoad];
    
    [self layoutCourseInfoCard];
    [self layoutNavigationBarTitle];
    [self pullCourseData];
}

- (void)pullCourseData {
    
    NSString *encoded = [self.course.displayTitle stringEncodedAsFirebaseKey];
    NSString *urlString = [NSString stringWithFormat:@"glaring-heat-9505.firebaseIO.com/%@", encoded];
    Firebase *root = [[Firebase alloc] initWithUrl:urlString];
    
    [root observeSingleEventOfType:FEventTypeValue withBlock:^(FDataSnapshot *snapshot) {
        NSError *error = nil;
        for (NSDictionary *reportDictionary in [snapshot.value allValues]) {
            QReport *report = [MTLJSONAdapter modelOfClass:[QReport class] fromJSONDictionary:reportDictionary error:&error];
            if (error) {
                NSLog(@"%@", error);
            } else {
                [self updateUIWithQReport:report];
            }
        }
    }];
}

- (void)layoutNavigationBarTitle {
    
    // Sets title bar appearance for the view
    CGRect frame = CGRectMake(0, 0, 0, 0);
    UILabel *label = [[UILabel alloc] initWithFrame:frame];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont fontWithName:@"AvenirNext-DemiBold" size:17];
    label.text = [NSString stringWithFormat:@"%@ %@", self.course.shortField, self.course.number];
    label.textColor = [UIColor whiteColor];
    [label sizeToFit];
    self.navigationItem.titleView = label;
}

- (NSAttributedString*)meetingStringForCourse:(Course*)course {
    
    NSMutableString *meetingString = [NSMutableString new];
    
    // Sorts days so they can be printed in order in label
    if (![course.meetings count] == 0)
    {
        NSSortDescriptor *sortDescriptor = [NSSortDescriptor sortDescriptorWithKey:@"day" ascending:YES];
        NSArray *sortedMeetingTimes = [course.meetings sortedArrayUsingDescriptors:[NSArray arrayWithObject:sortDescriptor]];
        
        for (Meeting *meeting in sortedMeetingTimes)
        {
            [meetingString appendFormat:@"%@, ", [Meeting abbreviatedStringForDayNumber:meeting.day]];
        }
        if (meetingString.length >= 2) {
            meetingString = [[meetingString substringToIndex:meetingString.length - 2] mutableCopy];
        }
        
        Meeting *meeting = sortedMeetingTimes.lastObject;
        [meetingString appendFormat:@" from %@", meeting.displayString];
    }
    else
    {
        [meetingString appendString:@"TBD"];
    }

    return [[NSAttributedString alloc] initWithString:meetingString];
}

- (void)layoutCourseInfoCard {
    
    self.titleLabel.text = self.course.title;
    self.titleLabel.textColor = [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1];

    
    //self.courseMeetingLabel
    //[label setFont:[UIFont fontWithName:@"AvenirNext-Regular" size:13]];
    
    AppDelegate *delegate = [UIApplication sharedApplication].delegate;
    NSManagedObjectContext *context = [delegate managedObjectContext];
    
    for (UIView *card in self.cards) {
        card.layer.cornerRadius = 4.0f;
        card.clipsToBounds = YES;
    }
    
    self.viewCommentsButton.layer.cornerRadius = 4.0f;
    
    self.descriptionLabel.text = [NSString stringWithFormat:@"%@", self.course.courseDescription];
    self.descriptionLabel.textColor = [UIColor colorWithRed:0.0/255.0 green:0.0/255.0 blue:0.0/255.0 alpha:1];
    
    NSMutableString *facultyString = [NSMutableString new];
    
    // Formats information from Faculty object for the view
    if (![self.course.faculty count] == 0)
    {
        // Lists faculty names
        for (Faculty *faculty in self.course.faculty)
        {
            [facultyString appendFormat:@"%@ %@, ", faculty.first, faculty.last];
        }
        facultyString = [[facultyString substringToIndex:[facultyString length] - 2] mutableCopy];
    }
    else
    {
        // If no faculty listed, then faculty is TBD
        [facultyString appendString:@"TBD"];
    }
    
    // Gives location of the course
    NSMutableString *locationString = [NSMutableString new];
    if (![self.course.locations count] == 0)
    {
        for (Location *location in self.course.locations)
        {
            [locationString appendFormat:@"%@ %@", location.building, location.room];
        }
    }
    else
    {
        [locationString appendString:@"TBD"];
    }
    
    // Does varied text coloring in the label, repeated for most information labels
    NSString *instructorString = [NSString stringWithFormat:@"%@", facultyString];
    NSMutableAttributedString *instructorLabel = [[NSMutableAttributedString alloc] initWithString:instructorString];
    
    NSString *tempLocationString = [NSString stringWithFormat:@"%@", locationString];
    NSMutableAttributedString *locationLabel = [[NSMutableAttributedString alloc] initWithString:tempLocationString];
    
    self.courseInstructorLabel.attributedText = instructorLabel;
    
    self.courseMeetingLabel.attributedText = [self meetingStringForCourse:self.course];
    //CGFloat width =  [self.courseMeetingLabel.text sizeWithAttributes:[UIFont fontWithName:@"AvenirNext-Bold" size:13]].width;
    
    NSDictionary *userAttributes =
        @{NSFontAttributeName: [UIFont fontWithName:@"AvenirNext-Bold" size:13],
          NSForegroundColorAttributeName: [UIColor blackColor]};
    const CGSize textSize = [self.courseMeetingLabel.text sizeWithAttributes: userAttributes];
    CGFloat textWidth = textSize.width;
    
    self.courseMeetingLabel.frame = CGRectMake(self.courseMeetingLabel.frame.origin.x, self.courseMeetingLabel.frame.origin.y, textWidth+2.0, self.courseMeetingLabel.frame.size.height);
    
    self.courseLocationLabel.attributedText = locationLabel;
    
    // Gets Gen. Ed. requirements of the course from numerical gen. ed. listings
    NSString *genEdString;
    if ([self.course.genEdOne intValue] == 0) {
        genEdString = @"None";
    }
    else {
        switch ([self.course.genEdOne intValue]) {
            case 1:
                genEdString = @"Aesthetic and Interpretive Understanding";
                break;
            case 2:
                genEdString = @"Culture and Belief";
                break;
            case 3:
                genEdString = @"Empirical and Mathematical Reasoning";
                break;
            case 4:
                genEdString = @"Ethical Reasoning";
                break;
            case 5:
                genEdString = @"Science of Living Systems";
                break;
            case 6:
                genEdString = @"Science of the Physical Universe";
                break;
            case 7:
                genEdString = @"Societies of the World";
                break;
            case 8:
                genEdString = @"United States in the World";
                break;
            default:
                break;
        }
    // Checks if the courses satisfies a second gen. ed. requirement
        if ([self.course.genEdTwo intValue] != 0)
        {
            switch ([self.course.genEdTwo intValue]) {
                case 1:
                    genEdString = [genEdString stringByAppendingString:@", Aesthetic and Interpretive Understanding"];
                    break;
                case 2:
                    genEdString = [genEdString stringByAppendingString:@", Culture and Belief"];
                    break;
                case 3:
                    genEdString = [genEdString stringByAppendingString:@", Empirical and Mathematical Reasoning"];
                    break;
                case 4:
                    genEdString = [genEdString stringByAppendingString:@", Ethical Reasoning"];
                    break;
                case 5:
                    genEdString = [genEdString stringByAppendingString:@", Science of Living Systems"];
                    break;
                case 6:
                    genEdString = [genEdString stringByAppendingString:@", Science of the Physical Universe"];
                    break;
                case 7:
                    genEdString = [genEdString stringByAppendingString:@", Societies of the World"];
                    break;
                case 8:
                    genEdString = [genEdString stringByAppendingString:@", United States in the World"];
                    break;
                default:
                    break;
            }
        }
    }
    // Says if no Gen. Ed. fulfillments were found
    if (!genEdString) {
        genEdString = @"None";
    }
    
    // Text color formatting
    NSString *tempNotesString = [NSString stringWithFormat:@"Notes: %@", self.course.notes];
    NSMutableAttributedString *notesLabel = [[NSMutableAttributedString alloc] initWithString:tempNotesString];
    [notesLabel addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor] range:NSMakeRange(0,7)];
    [notesLabel addAttribute:NSForegroundColorAttributeName value:[UIColor blackColor] range:NSMakeRange(7, self.course.notes.length)];
    
    //    NSString *tempCatNumString = [NSString stringWithFormat:@"Catalog Number: %@", [self.course.catalogNumber stringValue]];
    //    NSMutableAttributedString *catNumLabel = [[NSMutableAttributedString alloc] initWithString:tempCatNumString];
    //    [catNumLabel addAttribute:NSForegroundColorAttributeName value:[UIColor grayColor] range:NSMakeRange(0,16)];
    //    [catNumLabel addAttribute:NSForegroundColorAttributeName value:[UIColor blackColor] range:NSMakeRange(16, [self.course.catalogNumber stringValue].length)];
    //
    //
    NSString *tempGenEdString = [NSString stringWithFormat:@"%@", genEdString];
    NSMutableAttributedString *genEdLabel = [[NSMutableAttributedString alloc] initWithString:tempGenEdString];
    
    //    self.notesLabel.attributedText = notesLabel;
    //    self.catalogNumLabel.attributedText = catNumLabel;
    self.satisfiesLabel.attributedText = genEdLabel;
    
    
    self.courseMeetingLabel.frame = CGRectMake(self.courseMeetingLabel.frame.origin.x, self.courseMeetingLabel.frame.origin.y, textWidth+2.0, self.courseMeetingLabel.frame.size.height);
    
    self.courseLocationLabel.attributedText = locationLabel;
    
}

- (void)updateUIWithQReport:(QReport*)report {
    
    self.report = report;
//     Retrieves Q scores for course
//    NSArray *qTypes = @[@"difficulty", @"workload", @"overall"];
//    NSMutableDictionary *qScoresDict = [NSMutableDictionary new];
//    for (NSString *type in qTypes) {
//        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"QScore"];
//        request.predicate = [NSPredicate predicateWithFormat:@"catalogNumber = %@ AND type = %@", self.course.catalogNumber, type];
//        NSArray *result = [context executeFetchRequest:request error:nil];
//        if (result.count == 0)
//            return;
//        
//        QScore *score = result[0];
//        [qScoresDict setObject:score forKey:type];
//    }
    
//     Sets the controller's Q score variables
    //self.overallScore = qScoresDict[@"overall"];
    
//    self.overallScore =  [[QScore alloc] init];
//    self.overallScore.one = @1;
//    self.overallScore.two = @2;
//    self.overallScore.three = @3;
//    self.overallScore.four = @4;
//    self.overallScore.five = @5;
//    
//    self.difficultyScore = [[QScore alloc] init];
//    self.difficultyScore.one = @4;
//    self.difficultyScore.two = @2;
//    self.difficultyScore.three = @7;
//    self.difficultyScore.four = @4;
//    self.difficultyScore.five = @1;
//    
//    self.workloadScore = [[QScore alloc] init];
//    self.workloadScore.one = @0;
//    self.workloadScore.two = @2;
//    self.workloadScore.three = @4;
//    self.workloadScore.four = @3;
//    self.workloadScore.five = @4;
//    
//    
//    self.course.qOverall = @4.2;
//    self.course.qDifficulty = @3.5;
//    self.course.qWorkload = @2.1;

    
    NSString *tempOverallString = [NSString stringWithFormat:@"Q Overall/n%0.2f", [self.course.qOverall doubleValue]];
    NSMutableAttributedString *overallLabel = [[NSMutableAttributedString alloc] initWithString:tempOverallString];
    
    //NSString *tempDifficultyString = [NSString stringWithFormat:@"Difficulty/n%0.2f", [self.course.qDifficulty doubleValue]];
    NSString *tempDifficultyString = [NSString stringWithFormat:@"Difficulty\n3.4"];
    NSMutableAttributedString *difficultyLabel = [[NSMutableAttributedString alloc] initWithString:tempDifficultyString];
    
    NSString *tempWorkloadString = [NSString stringWithFormat:@"Workload/n%0.2f", [self.course.qWorkload doubleValue]];
    NSMutableAttributedString *workloadLabel = [[NSMutableAttributedString alloc] initWithString:tempWorkloadString];
    
    self.overallLabel.attributedText = overallLabel;
    self.difficultyLabel.attributedText = difficultyLabel;
    self.workloadLabel.attributedText = workloadLabel;
    
    QResponse *overallResponse = report.responses[@"Course Overall"];
    if (overallResponse) {
        NSString *overallString = [NSString stringWithFormat:@"Q Overall %0.2f", overallResponse.mean.doubleValue];
        self.overallLabel.attributedText = [[NSMutableAttributedString alloc] initWithString:overallString];
    }
    
    QResponse *workloadResponse = report.responses[@"Workload (hours per week)"];
    if (workloadResponse) {
        NSString *workloadString = [NSString stringWithFormat:@"Workload %0.2f", workloadResponse.mean.doubleValue];
        self.workloadLabel.attributedText = [[NSMutableAttributedString alloc] initWithString:workloadString];
    }
    
    // Sets all the information for the Q score bar graph
    // From example of how to implement the graph on the graph's Github repository
    // Michalkonturek/GraphKit (the source of the bar graph)
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    self.view.backgroundColor = [UIColor gk_cloudsColor];
    
    [self updateGraphWithBreakdown:overallResponse.breakdown];
    
    self.graphView.barWidth = 28;
    self.graphView.barHeight = 150;
    self.graphView.marginBar = 16;
    self.graphView.animationDuration = 2.0;
    
    self.graphView.dataSource = self;
    
    [self.graphView draw];
    
    self.green = YES;
    
    float height = [UILabel heightForString:self.descriptionLabel.text width:self.descriptionLabel.bounds.size.width - 40 font:self.descriptionLabel.font];
    self.descriptionHeightConstraint.constant = height;
    
    [self.view setNeedsLayout];
    
    int j = 0;
    for (UIButton *qScoreButton in self.qScoreButtons) {
        [qScoreButton addTarget:self action:@selector(qScoreButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        qScoreButton.tag = j;
        j++;
    }
}

- (void)updateGraphWithBreakdown:(NSArray*)breakdown {
    
    if (!breakdown.count) {
        return;
    }
    
    self.labels = breakdown;
    
    NSMutableArray *data = [NSMutableArray array];
    
    double largest = 0;
    for (NSString *valueString in breakdown) {
        NSInteger doubleValue = valueString.doubleValue;
        if (doubleValue > largest)
            largest = doubleValue;
    }
    
    // Calculates ratio to proportion all the scores
    double ratio = 100.0/largest;
    
    for (NSString *valueString in breakdown) {
        NSInteger doubleValue = valueString.doubleValue;
        [data addObject:@(doubleValue*ratio)];
    }
    
    self.data = [NSArray arrayWithArray:data];
    
    [self selectButton:self.qScoreButtons[1] inArray:self.qScoreLabels];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    [self.scrollView setContentSize:self.contentView.frame.size];
    
    CGFloat satisfiesBottom = self.satisfiesLabel.frame.origin.y + self.satisfiesLabel.frame.size.height;
    
    CGRect newFrame = self.infoView.frame;
    newFrame.size.height = satisfiesBottom + 10;
    
    [self.infoView setFrame:newFrame];
    CGRect newQScoreFrame = self.QScoreView.frame;
    newQScoreFrame.origin.y = satisfiesBottom + 30;
    [self.QScoreView setFrame:newQScoreFrame];
}

- (void)qScoreButtonPressed:(UIButton*)senderButton {
    
    self.selectedQScoreIndex = senderButton.tag;
    [self selectButton:senderButton inArray:self.qScoreLabels];
    for (UIButton *button in self.qScoreButtons) {
        if (button.selected && button.tag != senderButton.tag) {
            [self selectButton:button inArray:self.qScoreLabels];
        }
    }
}

- (void)selectButton:(UIButton*)button inArray:(NSArray*)array {
    
    if (button.selected == NO)
    {
        for (UIButton *buttons in self.qScoreButtons)
        {
            buttons.selected = NO;
            UILabel *label = array[buttons.tag];
            [label setFont:[UIFont fontWithName:@"AvenirNext-Regular" size:13]];
        }
        
        button.selected = YES;
        UILabel *label = array[button.tag];
        [label setFont:[UIFont fontWithName:@"AvenirNext-Bold" size:13]];
        
        switch (button.tag) {
            case 0:
                break;
            case 1:
                break;
            case 2:
                break;
            default:
                break;
        }
    }
}

- (void)updateGraph:(NSInteger)data {
    
    if (data == 0) {
        self.labels = @[@"1", @"3", @"4", @"5", @"5"];
        
        NSArray *properties = @[@"one", @"two", @"three", @"four", @"five"];
        NSInteger largest = 5;
        NSString *largestBar;
        NSNumber *ratio = [NSNumber numberWithDouble:((double)100/(double)largest)];
        self.data = @[[NSNumber numberWithDouble:1.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:3.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:4.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:5.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:5.0*ratio.doubleValue]
                      ];
        
    }
    else if (data == 1)
    {
        self.labels = @[@"2", @"3", @"4", @"1", @"5"];
        
        NSArray *properties = @[@"one", @"two", @"three", @"four", @"five"];
        NSInteger largest = 5;
        NSString *largestBar;
        NSNumber *ratio = [NSNumber numberWithDouble:((double)100/(double)largest)];
        self.data = @[[NSNumber numberWithDouble:2.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:3.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:4.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:1.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:5.0*ratio.doubleValue]
                      ];
    }
    else
    {
        self.labels = @[@"4", @"3", @"2", @"5", @"2"];
        
        NSArray *properties = @[@"one", @"two", @"three", @"four", @"five"];
        NSInteger largest = 5;
        NSString *largestBar;
        NSNumber *ratio = [NSNumber numberWithDouble:((double)100/(double)largest)];
        self.data = @[[NSNumber numberWithDouble:4.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:3.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:2.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:5.0*ratio.doubleValue],
                      [NSNumber numberWithDouble:2.0*ratio.doubleValue]
                      ];
    }
    
    self.graphView.dataSource = self;
    [self.graphView draw];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (IBAction)viewCommentsButtonClicked:(id)sender {
    
    if (!self.report.comments.count) {
        [self.viewCommentsButton setTitle:@"No comments reported :(" forState:UIControlStateNormal];
        return;
    }
    
    UIStoryboard *main = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    CommentsViewController *controller = [main instantiateViewControllerWithIdentifier:@"comments"];
    controller.report = self.report;
    [self.navigationController pushViewController:controller animated:YES];
}

- (IBAction)onButtonFill:(id)sender {
    [self.graphView draw];
}

- (IBAction)onButtonChange:(id)sender {
    self.green = !self.green;
    self.graphView.barColor = (self.green) ? [UIColor gk_turquoiseColor] : [UIColor gk_amethystColor];
}

- (IBAction)onButtonReset:(id)sender {
    [self.graphView reset];
}

// Code from third-party GraphKit repository for bar graph on Github
#pragma mark - GKBarGraphDataSource

- (NSInteger)numberOfBars {
    return [self.data count];
}

- (NSNumber *)valueForBarAtIndex:(NSInteger)index {
    NSString *valueString = self.data[index];
    return @(valueString.intValue);
}

- (UIColor *)colorForBarAtIndex:(NSInteger)index {
    return [UIColor colorWithRed:31.0/255.0 green:148.0/255.0 blue:255.0/255.0 alpha:1];
}

- (CFTimeInterval)animationDurationForBarAtIndex:(NSInteger)index {
    CGFloat percentage = [[self valueForBarAtIndex:index] doubleValue];
    percentage = (percentage / 100);
    return (self.graphView.animationDuration * percentage);
}

- (NSString *)titleForBarAtIndex:(NSInteger)index {
    NSNumber *value = self.labels[index];
    return value.stringValue;
}

@end
