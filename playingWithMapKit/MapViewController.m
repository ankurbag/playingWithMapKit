//
//  ViewController.m
//  playingWithMapKit
//
//  Created by Xida Zheng on 1/2/15.
//  Copyright (c) 2015 xidazheng. All rights reserved.
//

#import "MapViewController.h"
#import "ResultsTableViewController.h"
#import "MultilineAnnotationView.h"

@interface MapViewController ()
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UITextField *searchText;
@property (strong, nonatomic) NSMutableArray *matchingItems;
- (IBAction)zoomIn:(id)sender;
- (IBAction)changeMapType:(id)sender;
- (IBAction)textFieldReturn:(id)sender;

@end

@implementation MapViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.navigationItem.title = @"LunchTime";
    self.searchText.placeholder = @"What are you feel?";
    [self.navigationItem.rightBarButtonItem setTitle:@""];
    [self.navigationItem.rightBarButtonItem setEnabled:NO];
    self.navigationItem.backBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStylePlain target:nil action:nil];
    
    CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
    NSLog(@"%d", status);
    
    if (status == kCLAuthorizationStatusRestricted || status == kCLAuthorizationStatusDenied) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Permission to Access Location Not Received" message:@"Please Turn On Location Sharing in Settings" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *defaultAction = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        }];
        [alert addAction:defaultAction];

        [self presentViewController:alert animated:YES completion:nil];
    } else {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        
        if (status == kCLAuthorizationStatusNotDetermined) {
            NSLog(@"requestWhenInUseAuthorization reached");
            [self.locationManager requestWhenInUseAuthorization];
        } else if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
            
            if ([CLLocationManager locationServicesEnabled]) {
                NSLog(@"showsUserLocation reached");
                self.mapView.showsUserLocation = YES;
            }
        }
    }
    
    self.mapView.delegate = self;
    
}


//need a handler for status messages because it comes up in two places

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    NSLog(@"didChangeAuthorizationStatus %d", status);
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        
        if ([CLLocationManager locationServicesEnabled]) {
            [self.locationManager startUpdatingLocation];
            self.mapView.showsUserLocation = YES;
        }
    }

}

- (void)mapView:(MKMapView *)mapView didUpdateUserLocation:(MKUserLocation *)userLocation
{
//    self.mapView.centerCoordinate = userLocation.location.coordinate;
}

- (IBAction)zoomIn:(id)sender {
    MKUserLocation *userLocation = self.mapView.userLocation;
    MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(userLocation.location.coordinate, 1000, 1000);
    [self.mapView setRegion:region animated:YES];
    
//    NSLog(@"%f %f %f %f", region.center.latitude, region.center.longitude, region.span.latitudeDelta, region.span.longitudeDelta);
//    NSLog(@"%f %f %f %f", self.mapView.region.center.latitude, self.mapView.region.center.longitude, self.mapView.region.span.latitudeDelta, self.mapView.region.span.longitudeDelta);
}

- (IBAction)changeMapType:(id)sender {
    if (self.mapView.mapType == MKMapTypeStandard) {
        self.mapView.mapType = MKMapTypeHybrid;
    }else {
        self.mapView.mapType = MKMapTypeStandard;
    }
}

- (IBAction)textFieldReturn:(id)sender {
    [sender resignFirstResponder];
    [self.mapView removeAnnotations:[self.mapView annotations]];
    [self performSearch];
}

- (void) mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views
{
    NSLog(@"Did addAnnotationViews %@", views);
}

- (MKAnnotationView *) mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    NSLog(@"viewForAnnotation %@", annotation);
    
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        MultilineAnnotationView *pin = (MultilineAnnotationView *) [self.mapView dequeueReusableAnnotationViewWithIdentifier: @"currentLocation"];
        if (pin == nil) {
            pin = [[MultilineAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier: @"currentLocation"];
        } else {
            pin.annotation = annotation;
        }
        pin.pinColor = MKPinAnnotationColorGreen;
        pin.canShowCallout = NO;
        
        CLGeocoder *geocoder = [[CLGeocoder alloc] init];

        [geocoder reverseGeocodeLocation:((MKUserLocation *) annotation).location completionHandler:^(NSArray *placemarks, NSError *error) {
            if ([placemarks count]>0) {
                CLPlacemark *placemark = placemarks[0]; //Only returns one
                NSArray *formattedAddressLines = placemark.addressDictionary[@"FormattedAddressLines"];
                NSString *street = formattedAddressLines[0];
                NSString *cityState = [formattedAddressLines[1] substringToIndex:[formattedAddressLines[1] length]-5];
                NSString *country = formattedAddressLines[2];
                
                [(MKUserLocation *)annotation setTitle:[NSString stringWithFormat:@" %@ \n %@\n %@", street, cityState, country]];
            }
        }];
        
        return pin;
    }
    
    return nil;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    NSLog(@"didSelectAnnotationView %@", view);
    if ([view isKindOfClass:[MultilineAnnotationView class]]) {
        [self zoomIn:nil];
    }
    
}

- (void) performSearch {
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = self.searchText.text;
    request.region = self.mapView.region;
    
    self.matchingItems = [[NSMutableArray alloc] init];
    
    MKLocalSearch *search = [[MKLocalSearch alloc] initWithRequest:request];
    
    [search startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        __block MKPointAnnotation *firstAnnotation;
        
        if (response.mapItems.count == 0) {
            NSLog(@"No Matches");
        }else
        {
            [response.mapItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                MKMapItem *item = obj;
                [self.matchingItems addObject:item];
                MKPointAnnotation *annotation = [[MKPointAnnotation alloc] init];
                annotation.coordinate = item.placemark.coordinate;
                annotation.title = item.name;
                [self.mapView addAnnotation:annotation];
                
                if (idx == 0) {
                    firstAnnotation = annotation;
                }
            }];
            
            [self.navigationItem.rightBarButtonItem setTitle:@"Results"];
            [self.navigationItem.rightBarButtonItem setEnabled:YES];
        }
        
        [self.mapView selectAnnotation:firstAnnotation animated:YES];
    }];
    
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    ResultsTableViewController *destination = [segue destinationViewController];
    destination.mapItems = self.matchingItems;
    destination.startingRegion = self.mapView.region;
}

- (void) touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self.searchText resignFirstResponder];
}

@end
