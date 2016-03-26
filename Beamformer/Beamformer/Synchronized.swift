import Foundation



class Synchronized
{
    private static var sharedInstance = Synchronized()

    private var locksTableLock: Int32
    private let locksTable: NSMapTable

    

    static func synchronized(object: AnyObject, block: Void -> Void)
    {
        sharedInstance.iSynchronized(object, block: block)
    }

    private init()
    {
        self.locksTableLock = OS_SPINLOCK_INIT
        self.locksTable = NSMapTable.weakToWeakObjectsMapTable()
    }

    private func iSynchronized(object: AnyObject, block: Void -> Void)
    {
        OSSpinLockLock(&locksTableLock)
        var lock = locksTable.objectForKey(object) as! NSRecursiveLock?
        if lock == nil {
            lock = NSRecursiveLock()
            locksTable.setObject(lock!, forKey: object)
        }

        OSSpinLockUnlock(&locksTableLock)
        lock!.lock()
        block()
        lock!.unlock()
    }
}