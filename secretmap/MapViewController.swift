/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Primary view controller for what is displayed by the application.
 In this class we configure an MKMapView to display a floorplan,
 recieve location updates to determine floor number, as well as
 provide a few helpful debugging annotations.
 We will also show how to highlight a region that you have defined in
 PDF coordinates but not Latitude  Longitude.
 */

import CoreLocation
import Foundation
import MapKit

import EstimoteProximitySDK

/**
 Primary view controller for what is displayed by the application.
 
 In this class we configure an MKMapView to display a floorplan, recieve
 location updates to determine floor number, as well as provide a few helpful
 debugging annotations.
 
 We will also show how to highlight a region that you have defined in PDF
 coordinates but not Latitude & Longitude.
 */
class MapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {
    
    /// Outlet for the map view in the storyboard.
    @IBOutlet weak var mapView: MKMapView!
    
    // Action for toggle - toggle the zones
    @IBAction func switchToggled(_ sender: UISwitch) {
        if sender.isOn {
            getEventData()
        } else {
            self.mapView.removeOverlays(mapView.overlays)
            self.mapView.add(floorplan0)
        }
    }
    
    /// Outlet for the visuals switch at the lower-right of the storyboard.
    // @IBOutlet weak var debugVisualsSwitch: UISwitch!
    
    /**
     To enable user location to be shown in the map, go to Main.storyboard,
     select the Map View, open its Attribute Inspector and click the checkbox
     next to User Location
     
     The user will need to authorize this app to use their location either by
     enabling it in Settings or by selecting the appropriate option when
     prompted.
     */
    var locationManager: CLLocationManager!
    
    var hideBackgroundOverlayAlpha: CGFloat!
    
    /// Helper class for managing the scroll & zoom of the MapView camera.
    var visibleMapRegionDelegate: VisibleMapRegionDelegate!
    
    /// Store the data about our floorplan here.
    var floorplan: FloorplanOverlay!
    
    var debuggingOverlays: [MKOverlay]!
    var debuggingAnnotations: [MKAnnotation]!
    
    /// This property remembers which floor we're on.
    var lastFloor: CLFloor!
    
    var highlightZone = [ CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 0) ]
    
    var highlightedArea = MKPolygon()
    
    var zoned: Bool = false
    
    /**
     Set to false if you want to turn off auto-scroll & auto-zoom that snaps
     to the floorplan in case you scroll or zoom too far away.
     */
    var snapMapViewToFloorplan: Bool!
    
    /**
     Set to true when we reveal the MapKit tileset (by pressing the trashcan
     button).
     */
    var mapKitTilesetRevealed = false
    
    /// Call this to reset the camera.
    @IBAction func resetCamera(_ sender: AnyObject) {
        visibleMapRegionDelegate.mapViewResetCameraToFloorplan(mapView)
    }
    
    /**
     When the trashcan hasn't yet been pressed, this toggles the debug
     visuals. Otherwise, this toggles the floorplan.
     */
    @IBAction func toggleDebugVisuals(_ sender: AnyObject) {
        if (sender.isKind(of: UISwitch.classForCoder())) {
            let senderSwitch: UISwitch = sender as! UISwitch
            /*
             If we have revealed the mapkit tileset (i.e. the trash icon was
             pressed), toggle the floorplan display off.
             */
            if (mapKitTilesetRevealed == true) {
                if (senderSwitch.isOn == true) {
                    showFloorplan()
                } else {
                    hideFloorplan()
                }
            } else {
                if (senderSwitch.isOn == true) {
                    showDebugVisuals()
                } else {
                    hideDebugVisuals()
                }
            }
        }
    }
    
    /**
     Remove all the overlays except for the debug visuals. Forces the debug
     visuals switch off.
     */
    @IBAction func revealMapKitTileset(_ sender: AnyObject) {
        mapView.removeOverlays(mapView.overlays)
        mapView.removeAnnotations(mapView.annotations)
        // Show labels for restaurants, schools, etc.
        mapView.showsPointsOfInterest = true
        // Show building outlines.
        mapView.showsBuildings = true
        mapKitTilesetRevealed = true
        // Set switch to off.
        // debugVisualsSwitch.setOn(false, animated: true)
        showDebugVisuals()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager = CLLocationManager()
        
        // Ask for permission to use location
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        view.backgroundColor = UIColor.gray
        
        // === Configure our floorplan.
        
        /*
         We setup a pair of anchors that will define how the floorplan image
         maps to geographic co-ordinates.
         */
      
        // anchors for thin-dev-area.pdf
        let anchor1 = GeoAnchor(latitudeLongitudeCoordinate: CLLocationCoordinate2DMake(36.086811, -115.177325), pdfPoint: CGPoint(x: 0, y: 1454))
        let anchor2 = GeoAnchor(latitudeLongitudeCoordinate: CLLocationCoordinate2DMake(36.086811, -115.178535), pdfPoint: CGPoint(x: 2213, y: 1454))
        
        let anchorPair = GeoAnchorPair(fromAnchor: anchor1, toAnchor: anchor2)
        
    
        // pdf for sample backend pdf
//        let pdfUrl = URL(string: "http://169.60.16.83:31874/svg/think.pdf")!
        
        // pdf for 505 Howard Building
        // let pdfUrl = Bundle.main.url(forResource: "Building_1959_Floor_08", withExtension: "pdf", subdirectory:"Floorplans")!
        
        // pdf for think-dev-area-crop.pdf
//         let pdfUrl = Bundle.main.url(forResource: "think-dev-area", withExtension: "pdf", subdirectory:"Floorplans")!
        
        // pdf for think-dev-area cloud
        let pdfUrl = URL(string: "http://169.48.110.218/svg/think-dev-area.pdf")!
        
        
        floorplan = FloorplanOverlay(floorplanUrl: pdfUrl, withPDFBox: CGPDFBox.trimBox, andAnchors: anchorPair, forFloorLevel: 0)
        visibleMapRegionDelegate = VisibleMapRegionDelegate(floorplanBounds: floorplan.boundingMapRectIncludingRotations, boundingPDFBox: floorplan.floorplanPDFBox,
                                                            floorplanCenter: floorplan.coordinate,
                                                            floorplanUprightMKMapCameraHeading: floorplan.getFloorplanUprightMKMapCameraHeading())
        
        // === Initialize our view
        hideBackgroundOverlayAlpha = 1.0
        
//        // Disable tileset.
//        mapView.add(HideBackgroundOverlay.hideBackgroundOverlay(), level: .aboveRoads)
//
//        /*
//         The following are provided for debugging.
//         In production, you'll want to comment this out.
//         */
        debuggingOverlays = MapViewController.createDebuggingOverlaysForMapView(mapView!, aboutFloorplan: floorplan)
        debuggingAnnotations = MapViewController.createDebuggingAnnotationsForMapView(mapView!, aboutFloorplan: floorplan)
//
//        // Draw the floorplan!
        mapView.add(floorplan)
        
        // add the annotations - DEBUGGING
//        mapView.addAnnotations(debuggingAnnotations)

        
        /*
         By default, we listen to the scroll & zoom events to make sure that
         if the user scrolls/zooms too far away from the floorplan, we
         automatically bounce back. If you would like to disable this
         behavior, comment out the following line.
         */
        snapMapViewToFloorplan = true
        
        NotificationCenter.default.addObserver(self, selector: #selector(showZone(notification:)), name: Notification.Name.zoneEntered, object: nil)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        /*
         For additional debugging, you may prefer to use non-satellite
         (standard) view instead of satellite view. If so, uncomment the line
         below. However, satellite view allows you to zoom in more closely
         than non-satellite view so you probably do not want to leave it this
         way in production.
         */
//        mapView.mapType = MKMapTypeStandard
    }
    
    // request map-api server
    // this gets beacon data and adds it in map view
    func getEventData() {
        // _ = [CGPoint(x: 205.0, y: 335.3), CGPoint(x: 205.0, y: 367.3), CGPoint(x: 138.5, y: 367.3)]
//        var arrayOfZones: [[CGPoint]]
        let urlString = "http://169.48.110.218/events/think-dev-area"
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { (data, response, error) in
            if error != nil {
                print(error!.localizedDescription)
            }
            
            guard let data = data else { return }
            
            do {
                //Decode retrived data with JSONDecoder and assing type of Article object
                let event = try JSONDecoder().decode(Event.self, from: data)
                
//                print(event)
                
                for beacon in event.beacons {
                    print(beacon)
                    let highlightZone = [CGPoint(x: beacon.x, y: event.y - beacon.y),CGPoint(x: beacon.x, y: event.y - beacon.y - beacon.width),CGPoint(x: beacon.x + beacon.width, y: event.y - beacon.y - beacon.width),CGPoint(x: beacon.x + beacon.width, y: event.y - beacon.y)]
                    print(highlightZone)
                    let customHighlightRegion = self.floorplan0.polygonFromCustomPDFPath(highlightZone)
                    customHighlightRegion.title = "Hello World"
                    customHighlightRegion.subtitle = "This custom region will be highlighted in Yellow!"
                    self.mapView!.add(customHighlightRegion)
                }
                
            } catch let jsonError {
                print(jsonError)
            }
        }.resume()
    }
    
    /// Respond to CoreLocation updates
    func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        let location: CLLocation = userLocation.location!
        
        // CLLocation updates will not always have floor information...
        if (location.floor != nil) {
            // ...but when they do, take note!
            NSLog("Location (Floor %ld): %s", location.floor!, location.description)
            lastFloor = location.floor
            NSLog("We are on floor %ld", lastFloor.level)
        }
    }
    
    @objc func showZone(notification: NSNotification){
        
        if self.zoned == true{
            mapView!.remove(self.highlightedArea)
        }
        
        var yaxis:Int = 1455
        var width:Int = 0
        var y1:Int = 0
        var y2:Int = 0
        var x1:Int = 0
        var x2:Int = 0
        
        let pdfRegionToHighlight = [ CGPoint(x: 0, y: 1055), CGPoint(x: 0, y: 1455), CGPoint(x: 400, y: 1455), CGPoint(x: 400, y: 1055) ]
        
        if let dict = notification.object as! NSDictionary? {
            if let x_anchor = dict["x"] as? Int{
                x1 = x_anchor
            }

            if let y_anchor = dict["y"] as? Int{
                y1 = y_anchor
            }

            if let w = dict["width"] as? Int{
                width = w
                y2 = yaxis - y1 - width
                x2 = x1 + width
            }

            let highlightZone = [CGPoint(x: x1, y: y1), CGPoint(x: x1, y: y2), CGPoint(x: x2, y: y2), CGPoint(x: x2, y: y1)]
            
            self.highlightedArea = floorplan.polygonFromCustomPDFPath(highlightZone)
            self.highlightedArea.title = "Hello World"
            self.highlightedArea.subtitle = "This custom region will be highlighted in Yellow!"
            mapView!.add(self.highlightedArea)
            self.zoned = true

        }
    }
    
    /// Request authorization if needed.
    func mapViewWillStartLocatingUser(_ mapView: MKMapView) {
        switch (CLLocationManager.authorizationStatus()) {
        case CLAuthorizationStatus.notDetermined:
            // Ask the user for permission to use location.
            locationManager.requestWhenInUseAuthorization()
        case CLAuthorizationStatus.denied:
            NSLog("Please authorize location services for this app under Settings > Privacy")
        case CLAuthorizationStatus.authorizedAlways, CLAuthorizationStatus.authorizedWhenInUse, CLAuthorizationStatus.restricted:
            break
        }
    }
    
    /// Helper method that shows the floorplan.
    func showFloorplan() {
        mapView.add(floorplan)
        visibleMapRegionDelegate.mapViewResetCameraToFloorplan(mapView)
    }
    
    /// Helper method that hides the floorplan.
    func hideFloorplan() {
        mapView.remove(floorplan)
    }
    
    /// Helper function that shows the debug visuals.
    func showDebugVisuals() {
        // Make the background transparent to reveal the underlying grid.
        hideBackgroundOverlayAlpha = 0.5
        // Show debugging bounding boxes.
        mapView.addOverlays(debuggingOverlays, level: .aboveRoads)
        // Show debugging pins.
        mapView.addAnnotations(debuggingAnnotations)
    }
    
    /// Helper function that hides the debug visuals.
    func hideDebugVisuals() {
        mapView.removeAnnotations(debuggingAnnotations)
        mapView.removeOverlays(debuggingOverlays)
        hideBackgroundOverlayAlpha = 1.0
    }
    
    /**
     Check for when the MKMapView is zoomed or scrolled in case we need to
     bounce back to the floorplan. If, instead, you're using e.g.
     MKUserTrackingModeFollow then you'll want to disable
     snapMapViewToFloorplan since it will conflict with the user-follow
     scroll/zoom.
     */
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        if (snapMapViewToFloorplan == true) {
            visibleMapRegionDelegate.mapView(mapView, regionDidChangeAnimated:animated)
        }
    }
    
    /// Produce each type of renderer that might exist in our mapView.
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        
        if (overlay.isKind(of: FloorplanOverlay.self)) {
            let renderer: FloorplanOverlayRenderer = FloorplanOverlayRenderer(overlay: overlay as MKOverlay)
            return renderer
        }
        
        if (overlay.isKind(of: HideBackgroundOverlay.self) == true) {
            let renderer = MKPolygonRenderer(overlay: overlay as MKOverlay)
            
            /*
             HideBackgroundOverlay covers the entire world, so this means all
             of MapKit's tiles will be replaced with a solid white background
             */
            renderer.fillColor = UIColor.white.withAlphaComponent(hideBackgroundOverlayAlpha)
            
            // No border.
            renderer.lineWidth = 0.0
            renderer.strokeColor = UIColor.white.withAlphaComponent(0.0)
            
            return renderer
        }
        
        if (overlay.isKind(of: MKPolygon.self) == true) {
            let polygon: MKPolygon = overlay as! MKPolygon
            
            /*
             A quick and dirty MKPolygon renderer for addDebuggingOverlays
             and our custom highlight region.
             In production, you'll want to implement this more cleanly.
             "However, if each overlay uses different colors or drawing
             attributes, you should find a way to initialize that information
             using the annotation object, rather than having a large decision
             tree in mapView:rendererForOverlay:"
             
             See "Creating Overlay Renderers from Your Delegate Object"
             */
            if (polygon.title == "Hello World") {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.orange.withAlphaComponent(0.5)
                renderer.strokeColor = UIColor.orange.withAlphaComponent(0.0)
                renderer.lineWidth = 0.0
                return renderer
            }
            
            if (polygon.title == "debug") {
                let renderer = MKPolygonRenderer(polygon: polygon)
                renderer.fillColor = UIColor.gray.withAlphaComponent(0.1)
                renderer.strokeColor = UIColor.cyan.withAlphaComponent(0.5)
                renderer.lineWidth = 2.0
                return renderer
            }
        }
        
        NSException(name:NSExceptionName(rawValue: "InvalidMKOverlay"), reason:"Did you add an overlay but forget to provide a matching renderer here? The class was type \(type(of: overlay))", userInfo:["wasClass": type(of: overlay)]).raise()
        return MKOverlayRenderer()
    }
    
    /// Produce each type of annotation view that might exist in our MapView.
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        /*
         For now, all we have are some quick and dirty pins for viewing debug
         annotations. To learn more about showing annotations,
         see "Annotating Maps".
         */
        
        if (annotation.title! == "red") {
            let pinView = MKPinAnnotationView()
            pinView.pinTintColor = UIColor.red
            pinView.canShowCallout = true
            return pinView
        }
        
        if (annotation.title! == "green") {
            let pinView = MKPinAnnotationView()
            pinView.pinTintColor = UIColor.green
            pinView.canShowCallout = true
            return pinView
        }
        
        if (annotation.title! == "purple") {
            let pinView = MKPinAnnotationView()
            pinView.pinTintColor = UIColor.purple
            pinView.canShowCallout = true
            return pinView
        }
        
        return nil
    }
    
    /**
     If you have set up your anchors correctly, this function will create:
     1. a red pin at the location of your fromAnchor.
     2. a green pin at the location of your toAnchor.
     3. a purple pin at the location of the PDF's internal origin.
     
     Use these pins to:
     * Compare the location of pins #1 and #2 with the underlying Apple Maps
     tiles.
     + The pins should appear, on the real world, in the physical
     locations corresponding to the landmarks that you chose for each
     anchor.
     + If either pin does not seem to be at the correct position on Apple
     Maps, double-check for typos in the CLLocationCoordinate2D values
     of your GeoAnchor struct.
     * Compare the location of pins #1 and #2 with the matching colored
     squares drawn by FloorplanOverlayRenderer.m:drawDiagnosticVisuals on
     your floorplan overlay.
     + The red pin should appear at the same location as the red square
     the green pin should appear at the same location as the green
     square.
     + If either pin does not match the location of its corresponding
     square, you may be having problems with coordinate conversion
     accuracy. Try picking anchor points that are further apart.
     
     - parameter mapView: MapView to draw on.
     - parameter aboutFloorplan: floorplan from which we get anchors and
     coordinates.
     */
    class func createDebuggingAnnotationsForMapView(_ mapView: MKMapView, aboutFloorplan floorplan: FloorplanOverlay) -> [MKPointAnnotation] {
        // Drop a red pin on the fromAnchor latitudeLongitude location.
        let fromAnchor = MKPointAnnotation()
        fromAnchor.title = "red"
        fromAnchor.subtitle = "fromAnchor should be here"
        fromAnchor.coordinate = floorplan.geoAnchorPair.fromAnchor.latitudeLongitudeCoordinate
        
        // Drop a green pin on the toAnchor latitudeLongitude location.
        let toAnchor = MKPointAnnotation()
        toAnchor.title = "green"
        toAnchor.subtitle = "toAnchor should be here"
        toAnchor.coordinate = floorplan.geoAnchorPair.toAnchor.latitudeLongitudeCoordinate
        
        // Drop a purple pin showing the (0.0 pt, 0.0 pt) location of the PDF.
        let pdfOrigin = MKPointAnnotation()
        pdfOrigin.title = "purple"
        pdfOrigin.subtitle = "This is the 0.0, 0.0 coordinate of your PDF"
        pdfOrigin.coordinate = MKCoordinateForMapPoint(floorplan.pdfOrigin)
        
        return [fromAnchor, toAnchor, pdfOrigin]
    }
    
    /**
     Return an array of three debugging overlays. These overlays will show:
     1. the PDF Page Box that was selected for this floor.
     2. the boundingMapRect used to define the rendering of this floorplan by
     MKMapView.
     3. the boundingMapRectIncludingRotations used to define the rendering of
     this floorplan.
     
     Use these outlines to:
     * Ensure that #1 shows a polygon that is just small enough to enclose
     all of the important visual content in your floorplan.
     + If this polygon is much larger than your floorplan, you may
     experience runtime performance issues. In this case it's better
     to choose or define a smaller PDF Page Box.
     
     * Ensure that #2 shows a polygon that encloses your floorplan exactly.
     + If any important visual floorplan information is outside this
     polygon, those parts of the floorplan might not be displayed to
     the user, depending on their zoom & scrolling. In this case it's
     better to choose or define a larger PDF Page Box.
     
     * Ensure that #3 shows a polygon that is large enough to contain your
     floorplan comfortably, but still small enough to cause bounce-back
     when the user scrolls/zooms out too far.
     + The boundingMapRect is based on the PDF Page Box, so the best way
     to adjust the boundingMapRect is to get a more accurate PDF Page
     Box.
     + Note: In this sample code app we use the boundingMapRect also to
     determine the limits where zoom/scroll bounce-back takes place.
     */
    class func createDebuggingOverlaysForMapView(_ mapView: MKMapView, aboutFloorplan floorplan: FloorplanOverlay) -> [MKPolygon] {
        let floorplanPDFBox = floorplan.polygonFromFloorplanPDFBoxCorners
        floorplanPDFBox.title = "debug"
        floorplanPDFBox.subtitle = "PDF Page Box"
        
        let floorplanBoundingMapRect = floorplan.polygonFromBoundingMapRect
        floorplanBoundingMapRect.title = "debug"
        floorplanBoundingMapRect.subtitle = "boundingMapRect"
        
        let floorplanBoundingMapRectWithRotations = floorplan.polygonFromBoundingMapRectIncludingRotations
        floorplanBoundingMapRectWithRotations.title = "debug"
        floorplanBoundingMapRectWithRotations.subtitle = "boundingMapRectIncludingRotations"
        
        return [floorplanPDFBox, floorplanBoundingMapRect, floorplanBoundingMapRectWithRotations]
    }
}
