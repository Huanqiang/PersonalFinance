//
//  Zephyr.swift
//  Zephyr
//
//  Created by Arthur Ariel Sabintsev on 11/2/15.
//  Copyright © 2015 Arthur Ariel Sabintsev. All rights reserved.
//

import Foundation

/**

 Enumerates the Local (NSUserDefaults) and Remote (NSUNSUbiquitousKeyValueStore) data stores

 */
private enum ZephyrDataStore {
    case local  // NSUserDefaults
    case remote // NSUbiquitousKeyValueStore
}

open class Zephyr: NSObject {

    /**

     A debug flag.

     If **true**, then this will enable console log statements.

     By default, this flag is set to **false**.

     */
    open static var debugEnabled = false

    /**

     If **true**, then NSUbiquitousKeyValueStore.synchronize() will be called immediately after any change is made

     */
    open static var syncUbiquitousStoreKeyValueStoreOnChange = true

    /**

     The singleton for Zephyr.

     */
    fileprivate static let sharedInstance = Zephyr()

    /**

     A shared key that stores the last synchronization date between NSUserDefaults and NSUbiquitousKeyValueStore

     */
    fileprivate let ZephyrSyncKey = "ZephyrSyncKey"


    /**

     An array of keys that should be actively monitored for changes

     */
    fileprivate var monitoredKeys = [String]()

    /**

     An array of keys that are currently registered for observation

     */
    fileprivate var registeredObservationKeys = [String]()

    /**

     A queue used to serialize synchronization on monitored keys

     */
    fileprivate let zephyrQueue = DispatchQueue(label: "com.zephyr.queue", attributes: []);


    /**

     A session-persisted variable to directly access all of the NSUserDefaults elements

     */
    fileprivate var zephyrLocalStoreDictionary: [String: AnyObject] {
        get {
            return UserDefaults.standard.dictionaryRepresentation() as [String : AnyObject]
        }
    }

    /**

     A session-persisted variable to directly access all of the NSUbiquitousKeyValueStore elements

     */
    fileprivate var zephyrRemoteStoreDictionary: [String: AnyObject]  {
        get {
            return NSUbiquitousKeyValueStore.default().dictionaryRepresentation as [String : AnyObject]
        }
    }

    /**

     Zephyr's initialization method

     Do not call it directly.
     */
    override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(keysDidChangeOnCloud(_:)), name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForeground(_:)), name:
            NSNotification.Name.UIApplicationWillEnterForeground, object: nil)

        NSUbiquitousKeyValueStore.default().synchronize()
    }


    /**

     Zephyr's de-initialization method

     */
    deinit {
        zephyrQueue.sync(execute: {
            for key in self.registeredObservationKeys {
                UserDefaults.standard.removeObserver(self, forKeyPath: key)
            }
        })
    }

    /**

     Zephyr's synchronization method.

     Zephyr will synchronize all NSUserDefaults with NSUbiquitousKeyValueStore.

     If one or more keys are passed, only those keys will be synchronized.

     - parameter keys: If you pass a one or more keys, only those key will be synchronized. If no keys are passed, than all NSUserDefaults will be synchronized with NSUbiquitousKeyValueStore.

     */
    open static func sync(_ keys: String...) {
        if keys.count > 0 {
            sync(keys)
            return
        }

        switch sharedInstance.dataStoreWithLatestData() {

        case .local:

            printGeneralSyncStatus(false, destination: .remote)
            sharedInstance.zephyrQueue.sync {
                sharedInstance.syncToCloud()
            }
            printGeneralSyncStatus(true, destination: .remote)

        case .remote:

            printGeneralSyncStatus(false, destination: .local)
            sharedInstance.zephyrQueue.sync {
                sharedInstance.syncFromCloud()
            }
            printGeneralSyncStatus(true, destination: .local)

        }

    }

    /**

     Overloaded version of Zephyr's synchronization method, **sync(_:)**.

     This method will synchronize an array of keys between NSUserDefaults and NSUbiquitousKeyValueStore.

     - parameter keys: An array of keys that should be synchronized between NSUserDefaults and NSUbiquitousKeyValueStore.

     */
    open static func sync(_ keys: [String]) {

        switch sharedInstance.dataStoreWithLatestData() {

        case .local:

            printGeneralSyncStatus(false, destination: .remote)
            sharedInstance.zephyrQueue.sync {
                sharedInstance.syncSpecificKeys(keys, dataStore: .local)
            }
            printGeneralSyncStatus(true, destination: .remote)

        case .remote:

            printGeneralSyncStatus(false, destination: .local)
            sharedInstance.zephyrQueue.sync {
                sharedInstance.syncSpecificKeys(keys, dataStore: .remote)
            }
            printGeneralSyncStatus(true, destination: .local)

        }

    }

    /**

     Add specific keys to be monitored in the background. Monitored keys will automatically
     be synchronized between both data stores whenever a change is detected

     - parameter keys: Pass one or more keys that you would like to begin monitoring.

     */
    open static func addKeysToBeMonitored(_ keys: [String]) {

        for key in keys {

            if sharedInstance.monitoredKeys.contains(key) == false {
                sharedInstance.monitoredKeys.append(key)

                sharedInstance.zephyrQueue.sync {
                    sharedInstance.registerObserver(key)
                }
            }

        }
    }

    /**

     Overloaded version of the **addKeysToBeMonitored(_:)** method.

     Add specific keys to be monitored in the background. Monitored keys will automatically
     be synchronized between both data stores whenever a change is detected

     - parameter keys: Pass one or more keys that you would like to begin monitoring.

     */
    open static func addKeysToBeMonitored(_ keys: String...) {

        addKeysToBeMonitored(keys)

    }

    /**

     Remove specific keys from being monitored in the background.

     - parameter keys: Pass one or more keys that you would like to stop monitoring.

     */
    open static func removeKeysFromBeingMonitored(_ keys: [String]) {

        for key in keys {
            if sharedInstance.monitoredKeys.contains(key) == true {
                sharedInstance.monitoredKeys = sharedInstance.monitoredKeys.filter({$0 != key })

                sharedInstance.zephyrQueue.sync {
                    sharedInstance.unregisterObserver(key)
                }
            }
        }
    }

    /**

     Overloaded version of the **removeKeysFromBeingMonitored(_:)** method.

     Remove specific keys from being monitored in the background.

     - parameter keys: Pass one or more keys that you would like to stop monitoring.

     */
    open static func removeKeysFromBeingMonitored(_ keys: String...) {

        removeKeysFromBeingMonitored(keys)

    }

}

// MARK: Helpers

private extension Zephyr {

    /**

     Compares the last sync date between NSUbiquitousKeyValueStore and NSUserDefaults.

     If no data exists in NSUbiquitousKeyValueStore, then NSUbiquitousKeyValueStore will synchronize NSUserDefaults.
     If no data exists in NSUserDefaults, then NSUserDefaults will synchronize NSUbiquitousKeyValueStore.

     */
    func dataStoreWithLatestData() -> ZephyrDataStore {

        if let remoteDate = zephyrRemoteStoreDictionary[ZephyrSyncKey] as? Date,
            let localDate = zephyrLocalStoreDictionary[ZephyrSyncKey] as? Date {

                // If both localDate and remoteDate exist, compare the two, and the synchronize the data stores.
                return localDate.timeIntervalSince1970 > remoteDate.timeIntervalSince1970 ? .local : .remote

        } else {

            // If remoteDate doesn't exist, then assume local data is newer.
            guard let _ = zephyrRemoteStoreDictionary[ZephyrSyncKey] as? Date else {
                return .local
            }

            // If localDate doesn't exist, then assume that remote data is newer.
            guard let _ = zephyrLocalStoreDictionary[ZephyrSyncKey] as? Date else {
                return .remote
            }

            // If neither exist, synchronize local data store to iCloud.
            return .local
        }

    }

}

// MARK: Synchronizers

private extension Zephyr {

    /**

     Synchronizes specific keys to/from NSUbiquitousKeyValueStore and NSUserDefaults.

     - parameter keys: Array of leys to synchronize.
     - parameter dataStore: Signifies if keys should be synchronized to/from iCloud.

     */
    func syncSpecificKeys(_ keys: [String], dataStore: ZephyrDataStore) {

        for key in keys {

            switch dataStore {
            case .local:
                let value = zephyrLocalStoreDictionary[key]
                syncToCloud(key: key, value: value)
            case .remote:
                let value = zephyrRemoteStoreDictionary[key]
                syncFromCloud(key: key, value: value)
            }

        }

    }

    /**

     Synchronizes all NSUserDefaults to NSUbiquitousKeyValueStore.

     If a key is passed, only that key will be synchronized.

     - parameter key: If you pass a key, only that key will updated in NSUbiquitousKeyValueStore.
     - parameter value: The value that will be synchronized. Must be passed with a key, otherwise, nothing will happen.

     */
    func syncToCloud(key: String? = nil, value: AnyObject? = nil) {

        let ubiquitousStore = NSUbiquitousKeyValueStore.default()
        ubiquitousStore.set(Date(), forKey: ZephyrSyncKey)

        // Sync all defaults to iCloud if key is nil, otherwise sync only the specific key/value pair.
        guard let key = key else {
            for (key, value) in zephyrLocalStoreDictionary {
                unregisterObserver(key)
                ubiquitousStore.set(value, forKey: key)
                Zephyr.printKeySyncStatus(key, value: value, destination: .remote)
                if Zephyr.syncUbiquitousStoreKeyValueStoreOnChange {
                    ubiquitousStore.synchronize()
                }
                registerObserver(key)
            }

            return
        }

        unregisterObserver(key)

        if let value = value {
            ubiquitousStore.set(value, forKey: key)
            Zephyr.printKeySyncStatus(key, value: value, destination: .remote)
        }

        if Zephyr.syncUbiquitousStoreKeyValueStoreOnChange {
            ubiquitousStore.synchronize()
        }

        registerObserver(key)
    }

    /**

     Synchronizes all NSUbiquitousKeyValueStore to NSUserDefaults.

     If a key is passed, only that key will be synchronized.

     - parameter key: If you pass a key, only that key will updated in NSUserDefaults.
     - parameter value: The value that will be synchronized. Must be passed with a key, otherwise, nothing will happen.

     */
    func syncFromCloud(key: String? = nil, value: AnyObject? = nil) {

        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: ZephyrSyncKey)

        // Sync all defaults from iCloud if key is nil, otherwise sync only the specific key/value pair.
        guard let key = key else {
            for (key, value) in zephyrRemoteStoreDictionary {
                unregisterObserver(key)
                defaults.set(value, forKey: key)
                Zephyr.printKeySyncStatus(key, value: value, destination: .local)
                registerObserver(key)
            }

            return
        }

        unregisterObserver(key)

        if let value = value {
            defaults.set(value, forKey: key)
            Zephyr.printKeySyncStatus(key, value: value, destination: .local)
        } else {
            defaults.set(nil, forKey: key)
            Zephyr.printKeySyncStatus(key, value: nil, destination: .local)
        }

        registerObserver(key)
    }

}

// MARK: Observers

extension Zephyr {

    /**

     Adds key-value observation after synchronization of a specific key.

     - parameter key: The key that should be added and monitored.

     */
    fileprivate func registerObserver(_ key: String) {

        if key == ZephyrSyncKey {
            return
        }

        if !self.registeredObservationKeys.contains(key) {

            UserDefaults.standard.addObserver(self, forKeyPath: key, options: .new, context: nil)
            self.registeredObservationKeys.append(key)

        }

        Zephyr.printObservationStatus(key, subscribed: true)
    }

    /**

     Removes key-value observation before synchronization of a specific key.

     - parameter key: The key that should be removed from being monitored.

     */
    fileprivate func unregisterObserver(_ key: String) {

        if key == ZephyrSyncKey {
            return
        }

        if let index = self.registeredObservationKeys.index(of: key) {

            UserDefaults.standard.removeObserver(self, forKeyPath: key, context: nil)
            self.registeredObservationKeys.remove(at: index)

        }

        Zephyr.printObservationStatus(key, subscribed: false)
    }

    /**

     Observation method for UIApplicationWillEnterForegroundNotification

     */

    func willEnterForeground(_ notification: Notification) {
        NSUbiquitousKeyValueStore.default().synchronize()
    }

    /**

     Observation method for NSUbiquitousKeyValueStoreDidChangeExternallyNotification

     */
    func keysDidChangeOnCloud(_ notification: Notification) {
        if notification.name == NSUbiquitousKeyValueStore.didChangeExternallyNotification {

            guard let userInfo = notification.userInfo,
                let cloudKeys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String],
                let localStoredDate = zephyrLocalStoreDictionary[ZephyrSyncKey] as? Date,
                let remoteStoredDate = zephyrRemoteStoreDictionary[ZephyrSyncKey] as? Date, remoteStoredDate.timeIntervalSince1970 > localStoredDate.timeIntervalSince1970 else {
                    return
            }

            for key in monitoredKeys where cloudKeys.contains(key) {
                self.syncSpecificKeys([key], dataStore: .remote)
            }
        }
    }

    override open func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {

        guard let keyPath = keyPath, let object = object else {
            return
        }

        // Synchronize changes if key is monitored and if key is currently registered to respond to changes
        if monitoredKeys.contains(keyPath) {

            zephyrQueue.async(execute: {
                if self.registeredObservationKeys.contains(keyPath) {
                    if object is UserDefaults {
                        UserDefaults.standard.set(Date(), forKey: self.ZephyrSyncKey)
                    }

                    self.syncSpecificKeys([keyPath], dataStore: .local)
                }
            })

        }

    }

}

// MARK: Loggers

private extension Zephyr {

    /**

     Prints Zephyr's current sync status if

     debugEnabled == true

     - parameter finished: The current status of syncing

     */
    static func printGeneralSyncStatus(_ finished: Bool, destination dataStore: ZephyrDataStore) {

        if debugEnabled == true {
            let destination = dataStore == .local ? "FROM iCloud" : "TO iCloud."

            var message = "Started synchronization \(destination)"
            if finished == true {
                message = "Finished synchronization \(destination)"
            }

            printStatus(message)
        }
    }

    /**

     Prints the key, value, and destination of the synchronized information if

     debugEnabled == true

     - parameter key: The key being synchronized.
     - parameter value: The value being synchronized.
     - parameter destination: The data store that is receiving the updated key-value pair.

     */
    static func printKeySyncStatus(_ key: String, value: AnyObject?, destination dataStore: ZephyrDataStore) {

        if debugEnabled == true {
            let destination = dataStore == .local ? "FROM iCloud" : "TO iCloud."

            guard let value = value else {
                let message = "Synchronized key '\(key)' with value 'nil' \(destination)"
                printStatus(message)
                return
            }
            
            let message = "Synchronized key '\(key)' with value '\(value)' \(destination)"
            printStatus(message)
        }
    }
    
    /**
     
     Prints the subscription state for a specific key if
     
     debugEnabled == true
     
     - parameter key: The key being synchronized.
     - parameter subscribed: The subscription status of the key.
     
     */
    static func printObservationStatus(_ key: String, subscribed: Bool) {
        
        if debugEnabled == true {
            let subscriptionState = subscribed == true ? "Subscribed" : "Unsubscribed"
            let preposition = subscribed == true ? "for" : "from"
            
            let message = "\(subscriptionState) '\(key)' \(preposition) observation."
            printStatus(message)
        }
    }
    
    /**
     
     Prints a status to the console if
     
     debugEnabled == true
     
     - parameter status: The string that should be printed to the console.
     
     */
    static func printStatus(_ status: String) {
        if debugEnabled == true {
            print("[Zephyr] \(status)")
        }
    }
    
}
