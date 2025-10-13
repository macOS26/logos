import SwiftUI
import Combine

extension VectorDocument {

    func updateTextFontFamilyDirect(id: UUID, fontFamily: String) {
        saveToUndoStack()

        updateShapeByID(id) { shape in
            shape.typography?.fontFamily = fontFamily
        }
    }

    func updateTextFontVariantDirect(id: UUID, fontVariant: String) {
        saveToUndoStack()

        updateShapeByID(id) { shape in
            shape.typography?.fontVariant = fontVariant
        }
    }


    func updateTextFontSizePreview(id: UUID, fontSize: CGFloat) {
        if let textObject = findText(by: id) {
            var previewTypography = textObject.typography
            let oldFontSize = previewTypography.fontSize
            let lineHeightRatio = previewTypography.lineHeight / oldFontSize
            previewTypography.fontSize = fontSize
            previewTypography.lineHeight = fontSize * lineHeightRatio

            textPreviewTypography[id] = previewTypography

            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    func updateTextLineSpacingPreview(id: UUID, lineSpacing: Double) {
        if let textObject = findText(by: id) {
            var previewTypography = textPreviewTypography[id] ?? textObject.typography
            previewTypography.lineSpacing = lineSpacing

            textPreviewTypography[id] = previewTypography

            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    func updateTextLineHeightPreview(id: UUID, lineHeight: Double) {
        if let textObject = findText(by: id) {
            var previewTypography = textPreviewTypography[id] ?? textObject.typography
            previewTypography.lineHeight = lineHeight

            textPreviewTypography[id] = previewTypography

            NotificationCenter.default.post(
                name: Notification.Name("TextPreviewUpdate"),
                object: nil,
                userInfo: ["textID": id, "typography": previewTypography]
            )
        }
    }

    func clearTextPreviewTypography(id: UUID) {
        textPreviewTypography.removeValue(forKey: id)
    }

    // MARK: - Shape Preview Methods (for smooth sliders)

    func updateShapeFillOpacityPreview(id: UUID, opacity: Double) {
        shapePreviewFillOpacity[id] = opacity
        NotificationCenter.default.post(
            name: Notification.Name("ShapePreviewUpdate"),
            object: nil,
            userInfo: ["shapeID": id, "fillOpacity": opacity]
        )
    }

    func updateShapeStrokeOpacityPreview(id: UUID, opacity: Double) {
        shapePreviewStrokeOpacity[id] = opacity
        NotificationCenter.default.post(
            name: Notification.Name("ShapePreviewUpdate"),
            object: nil,
            userInfo: ["shapeID": id, "strokeOpacity": opacity]
        )
    }

    func updateShapeStrokeWidthPreview(id: UUID, width: Double) {
        shapePreviewStrokeWidth[id] = width
        NotificationCenter.default.post(
            name: Notification.Name("ShapePreviewUpdate"),
            object: nil,
            userInfo: ["shapeID": id, "strokeWidth": width]
        )
    }

    func clearShapePreview(id: UUID) {
        shapePreviewFillOpacity.removeValue(forKey: id)
        shapePreviewStrokeOpacity.removeValue(forKey: id)
        shapePreviewStrokeWidth.removeValue(forKey: id)
    }

    func updateTextFillColorInUnified(id: UUID, color: VectorColor) {
        updateShapeByID(id) { shape in
            if shape.typography != nil {
                shape.typography?.fillColor = color
                shape.typography?.fillOpacity = defaultFillOpacity
            } else if let textObject = findText(by: id) {
                shape.typography = textObject.typography
                shape.typography?.fillColor = color
                shape.typography?.fillOpacity = defaultFillOpacity
            }
        }
    }

    func updateTextTypographyInUnified(id: UUID, typography: TypographyProperties) {
        updateShapeByID(id) { shape in
            shape.typography = typography
        }
    }

    func updateTextStrokeColorInUnified(id: UUID, color: VectorColor) {
        updateShapeByID(id) { shape in
            if shape.typography != nil {
                shape.typography?.hasStroke = true
                shape.typography?.strokeColor = color
            } else if let textObject = findText(by: id) {
                shape.typography = textObject.typography
                shape.typography?.hasStroke = true
                shape.typography?.strokeColor = color
            }
        }
    }
}
