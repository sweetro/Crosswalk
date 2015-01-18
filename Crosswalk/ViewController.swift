//
//  ViewController.swift
//  Crosswalk
//
//  Created by Dylan Petro on 1/17/15.
//  Copyright (c) 2015 Dylan Petro. All rights reserved.
//

import UIKit
import CoreLocation
import AudioToolbox

class ViewController: UIViewController, CLLocationManagerDelegate  {
    
    
    @IBOutlet weak var alertThresholdLabel: UILabel!
    @IBOutlet weak var alertthresholdSlider: UISlider!
    @IBOutlet weak var locationFrequencyLabel: UILabel!
    @IBOutlet weak var locationFrequencySlider: UISlider!
    @IBOutlet weak var startStopButton: UIButton!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var intersectionLabel: UILabel!
    @IBOutlet weak var setDist: UILabel!
    @IBOutlet weak var smartSwitch: UISwitch!
    var alertDistThreshold = 0.3
    var locationDistFilter = 15.0
    let locationManager = CLLocationManager()
    var active = false
    var previousIntersectedStreetOne = "one"
    var previousIntersectedStreetTwo = "two"
    var currentStreet = "current"
    var previousDistanceToIntersection = 99999.0
    var alertTriggered = false
    var smartAlertOn = false
    
    
    /*Enables/Disables smart tracking*/
    @IBAction func enableSmart (){
        if(smartSwitch.on == true){
            smartAlertOn = true
            locationFrequencySlider.enabled = false
        }
        else{
            smartAlertOn = false
            locationFrequencySlider.enabled = true
            locationManager.distanceFilter = locationDistFilter //reset back
        }
        
    }
    
    /*Alert Threshold Handler*/
    @IBAction func alertThresholdSliderValueChanged(sender: UISlider) {
        var currentValue = sender.value
        alertThresholdLabel.text = NSString(format: "%.0f", currentValue) + " m"
        alertDistThreshold = Double(currentValue)/1000
    }
    
    /*Frequency of update from non smart mode*/
    @IBAction func locationFrequencySliderValueChanged(sender: UISlider) {
        var currentValue = sender.value
        locationFrequencyLabel.text = NSString(format: "%.0f", currentValue) + " m"
        locationDistFilter = Double(currentValue)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        UIApplication.sharedApplication().statusBarStyle = UIStatusBarStyle.LightContent
        
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    /*Start or stop tracking*/
    @IBAction func findMyLocation(sender: AnyObject) {
        if (active == false){
            locationManager.delegate = self
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.distanceFilter = locationDistFilter
            println(CLLocationManager.authorizationStatus().hashValue)
            if CLLocationManager.authorizationStatus() == .NotDetermined {
                locationManager.requestAlwaysAuthorization()
            }
            locationManager.startUpdatingLocation()
            let stopTitle = "Stop Assisting"
            startStopButton.setTitle(stopTitle, forState: UIControlState.Selected)
            startStopButton.setTitle(stopTitle, forState: UIControlState.Highlighted)
            startStopButton.setTitle(stopTitle, forState: UIControlState.Normal)
            startStopButton.backgroundColor = .darkGrayColor()
            startStopButton.setTitleColor(UIColor.whiteColor(), forState: UIControlState.Normal)
            active = true
            
        }
        else{
            let startTitle = "Start Assisting"
            startStopButton.setTitleColor(UIColor.blackColor(), forState:UIControlState.Normal)
            startStopButton.setTitle(startTitle, forState: UIControlState.Normal)
            startStopButton.backgroundColor = UIColor(red: CGFloat(254.0/255.0), green: CGFloat(238.0/255.0), blue: CGFloat(53.0/255.0), alpha: 1.0)
            locationManager.stopUpdatingLocation()
            active = false
        }
    }
    
    
    
    func locationManager(manager: CLLocationManager!, didUpdateLocations locations: [AnyObject]!) {
        CLGeocoder().reverseGeocodeLocation(manager.location, completionHandler: {(placemarks, error)->Void in
            if (error != nil) {
                println("Reverse geocoder failed with error" + error.localizedDescription)
                return
            }
            if placemarks.count > 0 {
                let pm = placemarks[0] as CLPlacemark
                self.parseLocationInfo(pm)
            } else {
                println("Problem with the data received from geocoder")
            }
        })
    }
    
    func locationManager(manager: CLLocationManager!, didFailWithError error: NSError!) {
        println("Error while updating location " + error.localizedDescription)
    }
    
    /*Used mainly for printing and calling main intersection activity*/
    func parseLocationInfo(placemark: CLPlacemark?) {
        if let containsPlacemark = placemark {
            //stop updating location to save battery life
            //] locationManager.stopUpdatingLocation()
            let locality = (containsPlacemark.locality != nil) ? containsPlacemark.locality : ""
            let postalCode = (containsPlacemark.postalCode != nil) ? containsPlacemark.postalCode : ""
            let administrativeArea = (containsPlacemark.administrativeArea != nil) ? containsPlacemark.administrativeArea : ""
            let country = (containsPlacemark.country != nil) ? containsPlacemark.country : ""
            let lat = containsPlacemark.location.coordinate.latitude
            let longit = containsPlacemark.location.coordinate.longitude
            let address = containsPlacemark.addressDictionary["Thoroughfare"] as NSString
            println(locality)
            println(postalCode)
            println(administrativeArea)
            println(country)
            println(lat)
            println(longit)
            println(address)
            self.searchGeo(containsPlacemark)
        }
    }
    
    /*Main activity, realistically needs a ton of refactoring*/
    func searchGeo(placemark: CLPlacemark!){
        let lat = placemark.location.coordinate.latitude
        let longit = placemark.location.coordinate.longitude
        let address = placemark.addressDictionary["Thoroughfare"] as NSString
        // The iTunes API wants multiple terms separated by + symbols, so replace spaces with + signs
        let latitude = NSString(format: "%.5f", lat)
        let longitude = NSString(format: "%.5f", longit)
        // Now escape anything else that isn't URL-friendly
        if let escapedLat = latitude.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding) {
            var escapedLong = longitude
            let urlPath = "http://api.geonames.org/findNearestIntersectionJSON?lat=\(escapedLat)&lng=\(escapedLong)&username=dpetro17"
            let url = NSURL(string: urlPath)
            let session = NSURLSession.sharedSession()
            let task = session.dataTaskWithURL(url!, completionHandler: {data, response, error -> Void in
                //println("Task completed")
                if(error != nil) {
                    // If there is an error in the web request, print it to the console
                    println(error.localizedDescription)
                }
                var err: NSError?
                
                var jsonResult = NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions.MutableContainers, error: &err) as NSDictionary
                if(err != nil) {
                    // If there is an error parsing JSON, print it to the console
                    println("JSON Error \(err!.localizedDescription)")
                }
                dispatch_async(dispatch_get_main_queue(), {
                    if let intersection = jsonResult["intersection"] as? NSDictionary {
                        if let distance = intersection["distance"] as? NSString {
                            var street1 = intersection["street1"] as String
                            var street2 = intersection["street2"] as String
                            var distanceMeters = distance.doubleValue * 1000.0
                            self.currentStreet = address
                            self.intersectionLabel.text = "NOT ON ROUTE" + " " + street1 + " " + street2
                            if((street1.rangeOfString(self.currentStreet) != nil) || (street2.rangeOfString(self.currentStreet) != nil)){
                                self.intersectionLabel.text = "\(distanceMeters) m" + " " + street1 + " " + street2
                                if (self.smartAlertOn) {
                                    self.smartAlert(street1, street2: street2, distance: distanceMeters)
                                }
                                var shouldAlert = self.shouldAlert(street1, street2: street2, distance: distanceMeters)
                                print(shouldAlert)
                                if (shouldAlert) {
                                    AudioServicesPlayAlertSound(SystemSoundID(kSystemSoundID_Vibrate))
                                    var localNotification:UILocalNotification = UILocalNotification()
                                    localNotification.alertAction = "OPEN"
                                    localNotification.alertBody = "Intersection of " + street1 + " and " + street2 + " in " + "\(distance.doubleValue * 1000.0)" + " m"
                                    localNotification.soundName = UILocalNotificationDefaultSoundName
                                    localNotification.fireDate = NSDate(timeIntervalSinceNow: 0)
                                    UIApplication.sharedApplication().scheduleLocalNotification(localNotification)
                                    
                                }
                                
                            }
                        }
                    }
                    
                })
            })
            task.resume()
        }
        
    }
    
    
    /*Determines if should send alert*/
    func shouldAlert(street1: String, street2: String, distance: Double) -> Bool{
        if ((previousIntersectedStreetOne == street1 && previousIntersectedStreetTwo == street2) ||
            (previousIntersectedStreetOne == street2 && previousIntersectedStreetTwo == street1)){
                if(distance < previousDistanceToIntersection){
                    previousDistanceToIntersection = distance
                    if(distance <= alertDistThreshold){
                        if(alertTriggered == false){
                            self.alertTriggered = true
                            return true
                        }
                    }
                }
                else{
                    previousDistanceToIntersection = distance
                }
        }
        else {
            previousIntersectedStreetOne = street1
            previousIntersectedStreetTwo = street2
            previousDistanceToIntersection = distance
            alertTriggered = false
            if(distance <= alertDistThreshold){
                if(alertTriggered == false){
                    self.alertTriggered = true
                    return true
                }
                
            }
            
        }
        return false
    }
    
    /*Determines necessary distance for alert to preserve battery*/
    func smartAlert(street1: String, street2: String, distance: Double) {
        println(previousIntersectedStreetOne)
        println(previousIntersectedStreetTwo)
        if ((previousIntersectedStreetOne == street1 && previousIntersectedStreetTwo == street2) ||
            (previousIntersectedStreetOne == street2 && previousIntersectedStreetTwo == street1)){
                if(alertTriggered == false){
                    if(alertDistThreshold < distance){
                        var walkSpeed = 1.25 //m/sec
                        var distInMeters = (distance - (alertDistThreshold * 1000))
                        var timeUntil = distInMeters/walkSpeed
                        locationManager.distanceFilter = distInMeters/2
                    }
                }
                
        }
        else {
            previousIntersectedStreetOne = street1
            previousIntersectedStreetTwo = street2
            locationManager.distanceFilter = 5.0 //retry to make sure still on same street
            
        }
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
}

