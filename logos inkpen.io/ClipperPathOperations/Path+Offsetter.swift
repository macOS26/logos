//
//  Path+Offsetter.swift
//  
//
//  Created by LuoHuanyu on 2020/2/1.
//

import CoreGraphics


extension ClipperPath {
    
    public func offset(_ delta: CGFloat) -> ClipperPaths {
        let o = Offsetter()
        var solution = ClipperPaths()
        o.addPath(self, joinType: .miter, endType: .closedLine)
        _ = try? o.execute(&solution, delta: delta)
        return solution
    }
    
}
