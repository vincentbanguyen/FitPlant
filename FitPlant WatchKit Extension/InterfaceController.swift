//
//  InterfaceController.swift
//  FitPlant WatchKit Extension
//
//  Created by Vincent Nguyen on 10/15/21.
//

import WatchKit
import Foundation
import SDWebImageLottieCoder
import UIKit
import HealthKit
import CoreData

class InterfaceController: WKInterfaceController {
    

    //core data stuf
    var plantData = [PlantData]()

    let healthStore = HKHealthStore()
    
    func autorizeHealthKit() {
        let healthKitTypes: Set = [
        HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!]

        healthStore.requestAuthorization(toShare: healthKitTypes, read: healthKitTypes) { _, _ in }
    }
    
    func getTodaysSteps(completion: @escaping (Double) -> Void) {
        let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(
            withStart: startOfDay,
            end: now,
            options: .strictStartDate
        )
        
        let query = HKStatisticsQuery(
            quantityType: stepsQuantityType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, _ in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(0.0)
                return
            }
            completion(sum.doubleValue(for: HKUnit.count()))
        }
        
        healthStore.execute(query)
    }
    
    var steps = 0
    var isPlaying = false
    var waterLevelPercentage = 0
   
    @IBOutlet weak var plant: WKInterfaceImage!
    @IBOutlet weak var waterLevelLabel: WKInterfaceLabel!
    
    @IBOutlet weak var cloudButton: WKInterfaceButton!
    @IBOutlet weak var rainVIew: WKInterfaceImage!
    
    @IBAction func cloudButtonPressed(sender: WKInterfaceButton)
    {
        
       
        if isPlaying == false && plantData[0].steps > 100 {
            isPlaying = true
            
            plantData[0].waterLevel += 2
            
            
            plantData[0].steps -= 100
            
            extensionDelegate?.saveContext()
            cloudButton.setTitle("\(plantData[0].steps)")
            waterLevelLabel.setText("\(plantData[0].waterLevel)%")
            loadAnimation(url: URL(string: "https://assets10.lottiefiles.com/packages/lf20_fo6qpunr.json")!)
            
            
            // changing plant image
            
            if plantData[0].waterLevel < 33 {
                plant.setImage(UIImage(named: "plantdead"))
            }
            else if plantData[0].waterLevel >= 33 {
                plant.setImage(UIImage(named: "plant"))
            }
            else {
                plant.setImage(UIImage(named: "planthappy"))
            }
        }
    }
    
    override func awake(withContext context: Any?) {
       
        // Configure interface objects here.
        loadData()
        autorizeHealthKit()
        // initliazer
        if plantData.count == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [self] in
                loadData()
                plantData[0].steps = 0
                print("DEBUGGG")
                plantData[0].waterLevel = 50
                extensionDelegate?.saveContext()
            }
        }
        
        else {
            
            if plantData[0].waterLevel > Int16(11) {
                plantData[0].waterLevel -= Int16.random(in: 5...10)
            }
            
            extensionDelegate?.saveContext()
            
            waterLevelLabel.setText("\(plantData[0].waterLevel)%")
            
            cloudButton.setTitle("\(Int(plantData[0].steps))")
            
            
            waterLevelLabel.setTextColor(UIColor(red: 58/255, green: 174/255, blue: 201/255, alpha: 1))
    //        stepsLabel.setTextColor(UIColor(red: 58/255, green: 174/255, blue: 201/255, alpha: 1))

            
            

            // whenever pulls tofays step,  if cloudsteps = 0 {  cloudsteps = pullSteps and previousPulledStpes = pullStepd }
            // push cloud steps, and previous pull steps to firebase.
            
            // when it pulls today steps again , additional = pulled steps - previousPUlled. then previouspull = pulled steps.
            // push previouspull to firebase.
            
            // cloudsteps += additionaStep.
            // push cloudsteps to firebase
            
            
            Timer.scheduledTimer(withTimeInterval: 5, repeats: true, block: { [self]_ in
                getTodaysSteps() { [self] (steps) in
                    if steps == 0.0 {
                        print("oh no")
                        print("steps :: \(Int(steps))")
                        
                        plantData[0].steps = Int16(steps)
                     
                        cloudButton.setTitle("\(Int(steps))")
                    }
                    else {
                        DispatchQueue.main.async {
                            
                            let additionalSteps = steps - Double(plantData[0].previousPulledSteps)
                            
                            plantData[0].previousPulledSteps = Int16(steps)
                            
                            plantData[0].steps += Int16(additionalSteps)
                       
                            cloudButton.setTitle("\(Int(plantData[0].steps))")
                            extensionDelegate?.saveContext()
                        }
                    }
                }
            })
        }
       
        
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
    }

    private var coder: SDImageLottieCoder?
    private var animationTimer: Timer?
    private var currentFrame: UInt = 0
    private var playing: Bool = false
    private var speed: Double = 1
    
    /// Loads animation data
    /// - Parameter url: url of animation JSON
    private func loadAnimation(url: URL) {
        let session = URLSession.shared
        let dataTask = session.dataTask(with: URLRequest(url: url)) { (data, response, error) in
            guard let data = data else { return }
            DispatchQueue.main.async {
                self.setupAnimation(with: data)
            }
        }
        dataTask.resume()
    }
    
    /// Decodify animation with given data
    /// - Parameter data: data of animation
    private func setupAnimation(with data: Data) {
        coder = SDImageLottieCoder(animatedImageData: data, options: [SDImageCoderOption.decodeLottieResourcePath: Bundle.main.resourcePath!])
        
        // resets to first frame
        currentFrame = 0
        setImage(frame: currentFrame)
        
        play()
    }
    
    /// Set current animation
    /// - Parameter frame: Set image for given frame
    private func setImage(frame: UInt) {
        guard let coder = coder else { return }
        rainVIew.setImage(coder.animatedImageFrame(at: frame))
    }
    
    /// Replace current frame with next one
    private func nextFrame() {
        guard let coder = coder else { return }

        currentFrame += 2
        // make sure that current frame is within frame count
        // if reaches the end, we set it back to 0 so it loops
        if currentFrame >= coder.animatedImageFrameCount {
            pause()
            isPlaying = false
        }
        
        setImage(frame: currentFrame)
    }
    
    
    
    /// Start playing animation
    private func play() {
        playing = true

        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.0000001, repeats: true, block: { (timer) in
            guard self.playing else {
                timer.invalidate()
                return
            }
            self.nextFrame()
        })
    }
    
    /// Pauses animation
    private func pause() {
        playing = false
        animationTimer?.invalidate()
    }
    
    
    func loadData(){
       // 1
       let dataRequest:NSFetchRequest<PlantData> = PlantData.fetchRequest()
            
       // 2
     
            
       // 3
       do {
           try plantData = moc!.fetch(dataRequest)
       }catch {
           print("Could not load data")
       }
            
    }
    
    


}
