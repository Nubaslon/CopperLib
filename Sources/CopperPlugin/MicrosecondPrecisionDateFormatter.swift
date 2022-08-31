//
//  MicrosecondPrecisionDateFormatter.swift
//  
//
//  Created by ANTROPOV Evgeny on 14.03.2022.
//

import Foundation

public final class MicrosecondPrecisionDateFormatter: DateFormatter {

    let cleanDateFormatter = DateFormatter()
    private let microsecondsPrefix = "."
    
    override public init() {
        super.init()
        locale = Locale(identifier: "en_US_POSIX")
    }
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func string(for obj: Any?) -> String? {
        return string(from: obj as! Date)
    }
    
    override public func string(from date: Date) -> String {
        cleanDateFormatter.dateFormat = "yyyy-MM-dd' 'HH:mm:ss|Z"
        let components = calendar.dateComponents(Set([Calendar.Component.nanosecond]), from: date)

        let nanosecondsInMicrosecond = Double(1000)
        let microseconds = lrint(Double(components.nanosecond!) / nanosecondsInMicrosecond)
        
        // Subtract nanoseconds from date to ensure string(from: Date) doesn't attempt faulty rounding.
        let updatedDate = calendar.date(byAdding: .nanosecond, value: -(components.nanosecond!), to: date)!
        
        let dateTimeString = cleanDateFormatter.string(from: updatedDate).components(separatedBy: "|")
        let string = String(format: "%@.%06ld%@",
                            dateTimeString.first ?? "",
                            microseconds,
                            dateTimeString.last ?? "")

        return string
    }
    
    override public func date(from string: String) -> Date? {
        cleanDateFormatter.dateFormat = "yyyy-MM-dd' 'HH:mm:ssZZZZZ"
        
        guard let microsecondsPrefixRange = string.range(of: microsecondsPrefix) else { return nil }
        let microsecondsWithTimeZoneString = String(string.suffix(from: microsecondsPrefixRange.upperBound))
        
        let nonDigitsCharacterSet = CharacterSet.decimalDigits.inverted
        guard let timeZoneRangePrefixRange = microsecondsWithTimeZoneString.rangeOfCharacter(from: nonDigitsCharacterSet) else { return nil }
        
        let microsecondsString = String(microsecondsWithTimeZoneString.prefix(upTo: timeZoneRangePrefixRange.lowerBound))
        guard let microsecondsCount = Double(microsecondsString) else { return nil }
        
        let dateStringExludingMicroseconds = string
            .replacingOccurrences(of: microsecondsString, with: "")
            .replacingOccurrences(of: microsecondsPrefix, with: "")
        
        guard let date = cleanDateFormatter.date(from: dateStringExludingMicroseconds) else { return nil }
        let microsecondsInSecond = Double(1000000)
        let dateWithMicroseconds = date + microsecondsCount / microsecondsInSecond
        
        return dateWithMicroseconds
    }
}
