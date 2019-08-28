// copyright dylan liu 2019
// yliu8949@gmail.com

import ARKit
import SceneKit
import UIKit

class ViewController: UIViewController, ARSessionDelegate {
    
    // MARK: Outlets
    @IBOutlet var sceneView: ARSCNView!
    var textureImage: UIImage!
    
    @IBAction func redButtonTouchUpInside(_ sender: Any) {
        lineColor = UIColor.red
    }
    
    @IBAction func blackButtonTouchUpInside(_ sender: Any) {
        lineColor = UIColor.black
    }
    
    @IBAction func clearButtonTouchUpInside(_ sender: Any) {
        clearDrawing()
    }
    
    // MARK: Properties
    var contentController : TexturedFace!
    var currentFaceAnchor: ARFaceAnchor?
    
    var lastPoint : CGPoint? = nil
    var lineColor = UIColor.red
    var lineWidth: CGFloat = 10.0
    var opacity: CGFloat = 1.0
    var material = SCNMaterial.init()
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let touch = touches.first else {
        return
      }
      lastPoint = transformToTextureCoordinates(screenCoordinates: touch.location(in: view))
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
      guard let touch = touches.first else {
        return
      }
        let currentPoint = transformToTextureCoordinates(screenCoordinates: touch.location(in: view))
        drawLine(from: lastPoint, to: currentPoint)
        lastPoint = currentPoint
    }
    
    func transformToTextureCoordinates(screenCoordinates: CGPoint) -> CGPoint? {
        let hitTestResults = sceneView.hitTest(screenCoordinates, options: nil)
        guard let result = hitTestResults.first else {
            return nil
        }
        let textureCoordinates = result.textureCoordinates(withMappingChannel: 0)
        return CGPoint(x: textureCoordinates.x * textureImage.size.width, y: textureCoordinates.y * textureImage.size.height)
    }
    
    func drawLine(from point1: CGPoint?, to point2: CGPoint?) {
        UIGraphicsBeginImageContext(textureImage.size)
        guard let context = UIGraphicsGetCurrentContext(), let fromPoint = point1, let toPoint = point2 else {
            return
        }
        
        textureImage?.draw(in: CGRect(x: 0, y: 0, width: textureImage.size.width, height: textureImage.size.height))
        context.move(to: fromPoint)
        context.addLine(to: toPoint)
        context.setLineCap(.round)
        context.setBlendMode(.overlay)
        context.setLineWidth(lineWidth)
        context.setStrokeColor(lineColor.cgColor)
        context.strokePath()
        /******************THIS LINE IS MAKING IT SLOW !!!********************/
        textureImage = UIGraphicsGetImageFromCurrentImageContext()
        /*******************Frame Rate 60 -> 30 on iPhone X********************/
        /**********************NEED OPTIMIZATION*************************/
        UIGraphicsEndImageContext()
    }
    
    func clearDrawing() {
        textureImage = UIImage.init(color: UIColor.clear, size: CGSize(width: 1024, height: 1024))
    }

    // MARK: - View Controller Life Cycle

    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        
        // DEBUG ONLY
        //sceneView.showsStatistics = true
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        clearDrawing()
        
        contentController = TexturedFace();
        
        let material = SCNMaterial.init()
        material.lightingModel = .physicallyBased
        material.diffuse.contents = textureImage
        
        if let anchor = currentFaceAnchor, let node = sceneView.node(for: anchor),
            let newContent = contentController.renderer(sceneView, nodeFor: anchor, with: material) {
            node.addChildNode(newContent)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
        resetTracking()
    }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    
    /// - Tag: ARFaceTrackingSetup
    func resetTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    // MARK: - Error handling
    func displayErrorMessage(title: String, message: String) {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
}

extension ViewController: ARSCNViewDelegate {
        
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let faceAnchor = anchor as? ARFaceAnchor else { return }
        currentFaceAnchor = faceAnchor

        material.lightingModel = .physicallyBased
        material.diffuse.contents = textureImage
        
        if node.childNodes.isEmpty, let contentNode = contentController.renderer(renderer, nodeFor: faceAnchor, with: material) {
            node.addChildNode(contentNode)
        }
    }
    
    /// - Tag: ARFaceGeometryUpdate
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard anchor == currentFaceAnchor,
            let contentNode = contentController.contentNode,
            contentNode.parent == node
            else { return }
        
        material.lightingModel = .physicallyBased
        material.diffuse.contents = textureImage
        contentController.renderer(renderer, didUpdate: contentNode, for: anchor, with: material)
    }
}

