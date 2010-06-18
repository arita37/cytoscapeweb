/*
  This file is part of Cytoscape Web.
  Copyright (c) 2009, The Cytoscape Consortium (www.cytoscape.org)

  The Cytoscape Consortium is:
    - Agilent Technologies
    - Institut Pasteur
    - Institute for Systems Biology
    - Memorial Sloan-Kettering Cancer Center
    - National Center for Integrative Biomedical Informatics
    - Unilever
    - University of California San Diego
    - University of California San Francisco
    - University of Toronto

  This library is free software; you can redistribute it and/or
  modify it under the terms of the GNU Lesser General Public
  License as published by the Free Software Foundation; either
  version 2.1 of the License, or (at your option) any later version.

  This library is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
  Lesser General Public License for more details.

  You should have received a copy of the GNU Lesser General Public
  License along with this library; if not, write to the Free Software
  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA
*/
package org.cytoscapeweb.view {
    import flare.animate.Parallel;
    import flare.display.DirtySprite;
    import flare.display.TextSprite;
    import flare.util.Arrays;
    import flare.vis.data.Data;
    import flare.vis.data.DataSprite;
    import flare.vis.data.EdgeSprite;
    import flare.vis.data.NodeSprite;
    import flare.vis.events.SelectionEvent;
    
    import flash.display.DisplayObject;
    import flash.events.KeyboardEvent;
    import flash.events.MouseEvent;
    import flash.ui.Keyboard;
    
    import org.cytoscapeweb.ApplicationFacade;
    import org.cytoscapeweb.events.DragEvent;
    import org.cytoscapeweb.events.GraphViewEvent;
    import org.cytoscapeweb.model.data.VisualStyleVO;
    import org.cytoscapeweb.util.Edges;
    import org.cytoscapeweb.util.ExternalFunctions;
    import org.cytoscapeweb.util.Groups;
    import org.cytoscapeweb.util.Nodes;
    import org.cytoscapeweb.util.Utils;
    import org.cytoscapeweb.util.VisualProperties;
    import org.cytoscapeweb.util.methods.$hasListener;
    import org.cytoscapeweb.view.components.GraphView;
    import org.cytoscapeweb.view.components.GraphVis;
    import org.cytoscapeweb.view.controls.EnclosingSelectionControl;
    import org.cytoscapeweb.view.controls.EventDragControl;
    import org.puremvc.as3.interfaces.INotification;


    public class GraphMediator extends BaseMediator {
    
        // ========[ CONSTANTS ]====================================================================
    
        /** Cannonical name of the Mediator. */
        public static const NAME:String = "GraphMediator";
        
        // ========[ PRIVATE PROPERTIES ]===========================================================

        private var _isMouseOverView:Boolean;
        private var _draggingNode:Boolean;
        private var _draggingGraph:Boolean;
        private var _selecting:Boolean;
        private var _ctrlDown:Boolean;
        private var _shiftDown:Boolean;
        
        private var _dragControl:EventDragControl;
        
        private function get dragControl():EventDragControl {
            if (_dragControl == null) {
                _dragControl = new EventDragControl(NodeSprite);
	            _dragControl.addEventListener(DragEvent.START, onDragNodeStart);
	            _dragControl.addEventListener(DragEvent.STOP, onEndDragNode);
	            _dragControl.addEventListener(DragEvent.DRAG, onDragNode);
            }
            
            return _dragControl;
        }
        
        private var _selectionControl:EnclosingSelectionControl;
        
        private function get selectionControl():EnclosingSelectionControl {
            if (_selectionControl == null) {
                _selectionControl = new EnclosingSelectionControl(DataSprite, 
                                                                  onSelect, onDeselect,
                                                                  graphView);
                _selectionControl.fireImmediately = false;
                // Set visual properties according to current style:
                setStyleToSelectionControl(configProxy.visualStyle);
                // It is important to attach it here, or the first attempt to use the
                // drag-selection will not work:
                selectionControl.attach(graphView);
            }
            
            return _selectionControl;
        }
        
        private function get _graphScale():Number {
            return vis.scaleX;
        }
   
        // ========[ PUBLIC PROPERTIES ]============================================================
   
        public function get graphView():GraphView {
            return viewComponent as GraphView;
        }
        
        public function get vis():GraphVis {
            return graphView.vis;
        }
   
        // ========[ CONSTRUCTOR ]==================================================================
   
        public function GraphMediator(viewComponent:Object) {
            super(NAME, viewComponent, this);
            graphView.addEventListener(GraphViewEvent.RENDER_INITIALIZE, onRenderInitialize, false, 0, true);
            graphView.addEventListener(GraphViewEvent.SCALE_CHANGE, onScaleChange, false, 0, true);
            graphView.addEventListener(MouseEvent.ROLL_OVER, onRollOverView, false, 0, true);
            graphView.addEventListener(MouseEvent.ROLL_OUT, onRollOutView, false, 0, true);
        }

        // ========[ PUBLIC METHODS ]===============================================================

        /** @inheritDoc */
        override public function getMediatorName():String {
            return NAME;
        }
        
        /** @inheritDoc */
        override public function listNotificationInterests():Array {
            return [ApplicationFacade.PAN_GRAPH,
                    ApplicationFacade.ENABLE_GRAB_TO_PAN,
                    ApplicationFacade.CENTER_GRAPH];
        }

        /** @inheritDoc */
        override public function handleNotification(note:INotification):void {
            switch (note.getName()) {
                case ApplicationFacade.ENABLE_GRAB_TO_PAN:
                    updateCursor();
                    break;
                case ApplicationFacade.PAN_GRAPH:
                    graphView.panGraph(-note.getBody().panX, -note.getBody().panY);
                    break;
                case ApplicationFacade.CENTER_GRAPH:
                    graphView.centerGraph();
                    break;
                default:
                    break;
            }
        }
        
        public function drawGraph():void {
            graphView.draw(graphProxy.graphData, configProxy.config, configProxy.visualStyle);
        }
        
        public function applyVisualStyle(style:VisualStyleVO):void {
            graphView.applyVisualStyle(style);
            setStyleToSelectionControl(style);
        }
        
        public function applyVisualBypass(style:VisualStyleVO):void {
            // TODO: make it faster (do not have to reapply everything)
            graphView.applyVisualStyle(style);
        }
        
        public function applyLayout(layout:Object):void {
            var par:Parallel = graphView.applyLayout(layout);
            par.play();
        }
        
        public function mergeEdges(merge:Boolean):void {
            vis.data.edges.setProperties(Edges.properties);
            graphView.updateLabels(Groups.EDGES);
        }
        
        public function updateLabels():void {
            graphView.updateLabels();
        }
        
        public function selectNodes(nodes:Array):void {
            if (nodes != null && nodes.length > 0) {
                graphView.selectNodes(nodes);
            }
        }
        
        public function selectEdges(edges:Array):void { 
            if (edges != null && edges.length > 0) {
                if (graphProxy.edgesMerged) {
                    // So merged edges are reset when a regular edge was selected.
                    // TODO: bring merged edges to front too!
                    vis.data.edges.setProperties(Edges.properties);
                } else {
                    graphView.selectEdges(edges);
                }
            }
        }
        
        public function deselectNodes(nodes:Array):void {
            graphView.deselectNodes(nodes);
        }
        
        public function deselectEdges(edges:Array):void {
            if (graphProxy.edgesMerged) {
                // So merged edges are reset when a regular edge was deselected.
                vis.data.edges.setProperties(Edges.properties);
            } else {
                graphView.resetAllEdges();
            }
        }
        
        public function updateView():void {
            vis.data.nodes.setProperties(Nodes.properties);
            vis.data.edges.setProperties(Edges.properties);
            vis.updateLabels(Groups.NODES);
            vis.updateLabels(Groups.EDGES);
            separateDisconnected();
        }
        
        public function updateFilters(updateNodes:Boolean, updateEdges:Boolean,
                                      updateAllProperties:Boolean):void {
            if (updateNodes) {
                if (updateAllProperties) {
                    vis.data.nodes.setProperties(Nodes.properties);
                } else {
                    for each (var n:NodeSprite in graphProxy.graphData.nodes) {
                        n.visible = Nodes.visible(n);
                    }
                }
                vis.updateLabels(Groups.NODES);
            }
            // When filtering nodes, it may be necessary to show/hide related edges as well:
            if (updateNodes || updateEdges) {
                if (updateAllProperties) {
                    vis.data.edges.setProperties(Edges.properties);
                } else {
                    var edges:* = graphProxy.graphData.edges;
                    var e:EdgeSprite;
                    for each (e in edges) {
                        e.visible = Edges.visible(e);
                    }
                }
                vis.updateLabels(Groups.EDGES);
            }
            separateDisconnected();
        }

        public function resetDataSprite(ds:DataSprite):void {
            if (ds is NodeSprite) graphView.resetNode(NodeSprite(ds));
            else if (ds is EdgeSprite) graphView.resetEdge(EdgeSprite(ds));
        }
        
        public function initialize(gr:String, items:Array):void { 
            // Set properties:
            var props:Object = gr === Groups.NODES ? Nodes.properties : Edges.properties;
            
            for (var name:String in props) {
                Arrays.setProperty(items, name, props[name], null);
            }
            
            vis.updateLabels(gr);
            addListeners(items);
            separateDisconnected();
        }
        
        public function separateDisconnected():void {
            vis.separateDisconnected();
        }
        
        public function dispose(items:Array):void {
            // Remove event listeners:
            for each (var ds:DataSprite in items) {
                disposeDataSprite(ds);
                
                if (ds is NodeSprite) {
                    // Also dispose its linked edges:
                    NodeSprite(ds).visitEdges(function(e:EdgeSprite):Boolean {
                        disposeDataSprite(e);
                        return false;
                    });
                }
            }
        }
        
        public function zoomGraphTo(scale:Number):void {
            graphView.zoomTo(scale);
            if (graphProxy.rolledOverNode != null) {
                // If zooming while mouse still over a node (e.g. using the keyboard to zoom),
                // its label size may be wrong, so let's reset it:
                rescaleNodeLabel(graphProxy.rolledOverNode, true);
            }
        }
        
        public function zoomGraphToFit():void {
            graphView.zoomToFit();
            graphView.centerGraph();
            if (graphProxy.rolledOverNode != null) {
                // If zooming while mouse still over a node (e.g. using the keyboard to zoom),
                // its label size may be wrong, so let's reset it:
                rescaleNodeLabel(graphProxy.rolledOverNode, true);
            }
        }
        
        // ========[ PRIVATE METHODS ]==============================================================

        private function onRenderInitialize(evt:GraphViewEvent):void {
            graphView.addEventListener(GraphViewEvent.LAYOUT_INITIALIZE, onLayoutInitialize, false, 0, true);
            graphView.addEventListener(GraphViewEvent.RENDER_COMPLETE, onRenderComplete, false, 0, true);
        }

        private function onRenderComplete(evt:GraphViewEvent):void {
            // First, add all the initial listeners to each NODE:
            // --------------------------------------------------
            addListeners(vis.data.nodes);
            addListeners(vis.data.edges);
            
            dragControl.attach(vis);
            
            // Then add the VIEW listeners:
            // ---------------------------------
            // 1. KEY events:
            graphView.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown, false, 0, true);
            graphView.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp, false, 0, true);
            // 2. DRAG the whole graph:
            graphView.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDownView, false, 0, true);
            // 3. Click:
            graphView.addEventListener(MouseEvent.CLICK, onClickView, false, 0, true);
            // 4. 2-Click:
            graphView.addEventListener(MouseEvent.DOUBLE_CLICK, onDoubleClickView, false, 0, true);
            
            evt.currentTarget.removeEventListener(evt.type, arguments.callee);
            sendNotification(ApplicationFacade.GRAPH_DRAWN);
        }
        
        private function onScaleChange(evt:GraphViewEvent):void {
            sendNotification(ApplicationFacade.ZOOM_CHANGED, evt.data);
        }
        
        private function onLayoutInitialize(evt:GraphViewEvent):void {
            graphView.addEventListener(GraphViewEvent.LAYOUT_COMPLETE, onLayoutComplete, false, 0, true);
            // Remove this listener, because reloading the swf file does not seem to kill it,
            // so it would have two listeners for the same action, after onRenderInitialize is called again:
            evt.currentTarget.removeEventListener(evt.type, arguments.callee);
            sendNotification(ApplicationFacade.INDETERMINATE_TASK_START);
        }
        
        private function onLayoutComplete(evt:GraphViewEvent):void {
            // We don't need this listener anymore:
            evt.currentTarget.removeEventListener(evt.type, arguments.callee);
            sendNotification(ApplicationFacade.INDETERMINATE_TASK_COMPLETE);
            // Add the LAYOUT INITIALIZE listener again:
            graphView.addEventListener(GraphViewEvent.LAYOUT_INITIALIZE, onLayoutInitialize, false, 0, true);
            
            // Call external listener:
            if ($hasListener("layout")) {
                var body:Object = { functionName: ExternalFunctions.INVOKE_LISTENERS, 
                                    argument: { type: "layout", value: configProxy.currentLayout } };
                sendNotification(ApplicationFacade.CALL_EXTERNAL_INTERFACE, body);
            }
        }
        
        private function addListeners(items:*):void {
            for each (var ds:DataSprite in items) {
                ds.doubleClickEnabled = true;
                
                if (ds is NodeSprite) {
                    ds.addEventListener(MouseEvent.ROLL_OVER, onRollOverNode, false, 0, true);
                    ds.addEventListener(MouseEvent.DOUBLE_CLICK, onDoubleClickNode, false, 0, true);
                    ds.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDownNode, false, 0, true);
                } else {
                    ds.addEventListener(MouseEvent.ROLL_OVER, onRollOverEdge, false, 0, true);
                    ds.addEventListener(MouseEvent.ROLL_OUT, onRollOutEdge, false, 0, true);
                    ds.addEventListener(MouseEvent.DOUBLE_CLICK, onDoubleClickEdge, false, 0, true);
                    ds.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDownEdge, false, 0, true);
                }
            }
        }
        
        // VIEW listener functions:
        // -----------------------------------------------------------------------------------------
        private function onKeyDown(evt:KeyboardEvent):void { trace("* Key DOWN :: " + evt.keyCode);
            var dirty:Boolean = _isMouseOverView || _selecting || _draggingGraph;
            
            if (evt.keyCode === Keyboard.CONTROL) {
                _ctrlDown = true;
                if (dirty)
                    updateCursor();
                if (graphProxy.rolledOverNode != null)
                    vis.showDragRectangle(graphProxy.rolledOverNode);
            } else if (evt.keyCode === Keyboard.SHIFT) {
                _shiftDown = true;
                if (!_ctrlDown && dirty)
                    updateCursor();
            }
        }
        
        private function onKeyUp(evt:KeyboardEvent):void { trace("* Key UP :: " + evt.keyCode);
            if (evt.keyCode === Keyboard.CONTROL) {
                _ctrlDown = false;
                if (_isMouseOverView) updateCursor();
                vis.hideDragRectangle();
            } else if (evt.keyCode === Keyboard.SHIFT) {
                _shiftDown = false;
                if (_isMouseOverView) updateCursor();
            }
        }

        private function onRollOverView(evt:MouseEvent):void { trace("<<<< Roll OVER [View]");
            _isMouseOverView = true;
            // Workaround to avoid the system cursor to disappear when drag-selecting and the mouse
            // roll out the Flash player area and then over again.
            // That happens when the plus cursor is being displayed.
            updateCursor();
        }
        
        private function onRollOutView(evt:MouseEvent):void { trace(">>>> Roll OUT [View]");
            _isMouseOverView = false;
            if (!_selecting && !_draggingNode && !_draggingGraph)
                sendNotification(ApplicationFacade.UPDATE_CURSOR);
        }
        
        private function onMouseDownView(evt:MouseEvent):void { trace("* Mouse DOWN [View]");
            if (_ctrlDown || (configProxy.grabToPanEnabled && graphProxy.rolledOverEdge == null)) {
                // PANNING the whole graph...
                _draggingGraph = true;
                updateCursor();

                // Remove other actions that should not occur when panning:
                selectionControl.detach();
                
                vis.startDrag();
                graphView.addEventListener(MouseEvent.MOUSE_UP, onMouseUpToStopPanning, false, 0, true);
            } else if (!configProxy.grabToPanEnabled) {
                updateCursor();
            	// Add the SELECTION CONTROL again:
                selectionControl.detach();
                selectionControl.attach(vis);
	
            	if (_shiftDown) {
            		// If SHIFT is pressed, add selected nodes to the selection group, thus
            		// ignoring the previously selected ones in order to avoid deselecting them
            		// "accidentally" when the selection rectangle encloses an already selected node:
            		selectionControl.filter = function(d:DisplayObject):Boolean {
            		    // TODO: filter edges OR nodes based on config param
            			return d is DataSprite && !DataSprite(d).props.$selected;
            		}
            	} else if (graphProxy.rolledOverEdge == null) {
            		// TODO: edges OR nodes based on config param
            		selectionControl.filter = DataSprite;
            		graphView.addEventListener(MouseEvent.MOUSE_UP, onMouseUpToDeselect, false, 0, true);
            	}

                graphView.addEventListener(MouseEvent.MOUSE_MOVE, onDragSelectionStart, false, 0, true);
            }
        }
        
        private function onMouseUpToDeselect(evt:MouseEvent):void { trace("* Mouse UP / Deselect all [View]");
            evt.currentTarget.removeEventListener(evt.type, arguments.callee);
            graphView.removeEventListener(MouseEvent.MOUSE_MOVE, onDragSelectionStart);
            sendNotification(ApplicationFacade.DESELECT_ALL, Groups.NONE);
        }
        
        private function onMouseUpToStopPanning(evt:MouseEvent):void { trace("* Mouse UP / STOP PANNING [View]");
            evt.currentTarget.removeEventListener(evt.type, arguments.callee);
            graphView.removeEventListener(MouseEvent.MOUSE_MOVE, onDragSelectionStart);
            vis.stopDrag();
            _draggingGraph = false;
            if (_isMouseOverView) updateCursor();
            else sendNotification(ApplicationFacade.UPDATE_CURSOR);
        }
        
        private function onClickView(evt:MouseEvent):void { trace("* Click [View]");
            sendNotification(ApplicationFacade.CLICK_EVENT,
                             { mouseX: evt.stageX, mouseY: evt.stageY });
        }
        
        private function onDoubleClickView(evt:MouseEvent):void { trace("* 2-CLICK [View]");
            if (!_shiftDown && configProxy.grabToPanEnabled)
                sendNotification(ApplicationFacade.DESELECT_ALL);
                
            sendNotification(ApplicationFacade.DOUBLE_CLICK_EVENT,
                             { mouseX: evt.stageX, mouseY: evt.stageY });
        }
        
        private function onDragSelectionStart(evt:MouseEvent):void { trace("* Drag Selection START [View]");
            evt.currentTarget.removeEventListener(evt.type, arguments.callee);
            graphView.addEventListener(MouseEvent.MOUSE_UP, onDragSelectionEnd, false, 0, true);
            graphView.removeEventListener(MouseEvent.MOUSE_UP, onMouseUpToDeselect);

            // If SHIFT key is pressed, keep the previously selected elements.
            // Otherwise, deselect everything first:
            if (!_shiftDown) sendNotification(ApplicationFacade.DESELECT_ALL, Groups.NONE);
            _selecting = true;
        }
        
        private function onDragSelectionEnd(evt:MouseEvent):void { trace("* Drag Selection END [View]");
            evt.currentTarget.removeEventListener(evt.type, arguments.callee);
            _selecting = false;
            if (_isMouseOverView) updateCursor();
            else sendNotification(ApplicationFacade.UPDATE_CURSOR);
        }
        
        // NODE listener functions:
        // -----------------------------------------------------------------------------------------
        private function onRollOverNode(evt:MouseEvent):void {
            if (_draggingNode || _draggingGraph || _selecting) return;

            var n:NodeSprite = evt.target as NodeSprite;
            n.addEventListener(MouseEvent.ROLL_OUT, onRollOutNode, false, 0, true);
            
            sendNotification(ApplicationFacade.ROLLOVER_EVENT, n);
            updateCursor();
            
            // When zoom < 100%, increase the label size to make it readable:
            if (_graphScale < 1) rescaleNodeLabel(n);
            
            if (_ctrlDown) vis.showDragRectangle(n);
        }
        
        private function onRollOutNode(evt:MouseEvent):void {
            if (_draggingNode || _draggingGraph || _selecting) return;

            var n:NodeSprite = evt.target as NodeSprite;
            sendNotification(ApplicationFacade.ROLLOUT_EVENT, n);
            
            n.removeEventListener(MouseEvent.ROLL_OUT, onRollOutNode);
            updateCursor();
            evt.stopImmediatePropagation();

            rescaleNodeLabel(n, true);
            vis.hideDragRectangle();
        }
        
        private function onMouseDownNode(evt:MouseEvent):void { trace("** Mouse DOWN [node]");
            var n:NodeSprite = evt.target as NodeSprite;
            n.addEventListener(MouseEvent.MOUSE_UP, onMouseUpNode, false, 0, true);
            n.addEventListener(MouseEvent.CLICK, onClickNode, false, 0, true);
            // Remove the SELECTION CONTROL:
            selectionControl.detach();
            // To avoid clicking the background:
            graphView.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDownView);
  
            // Dragging a disconnected component?
            if (_ctrlDown) {
                _draggingGraph = true;
                updateCursor();
                vis.showDragRectangle(n);
                var data:Data = vis.getDisconnectedData(n);
                graphView.bringAllToFront(data.nodes);
            }
            // Bring the target and the node to front:
            graphView.bringToFront(n);
        }
        
        private function onMouseUpNode(evt:MouseEvent):void { trace("** Mouse UP [node]");
            evt.currentTarget.removeEventListener(evt.type, arguments.callee);
            var n:NodeSprite = evt.target as NodeSprite;
            
            _draggingGraph = false;
            updateCursor();
            if (_ctrlDown) vis.showDragRectangle(n);
            
            // Return the MOUSE DOWN to the View, so panning is possible again:
            graphView.addEventListener(MouseEvent.MOUSE_DOWN, onMouseDownView, false, 0, true);
        }
        
        private function onClickNode(evt:MouseEvent):void { trace("** CLICK [node]");
            evt.currentTarget.removeEventListener(evt.type, arguments.callee);
            evt.stopImmediatePropagation();
            
            if (!_draggingGraph && !evt.ctrlKey) {
                var n:NodeSprite = evt.target as NodeSprite;
                sendNotification(ApplicationFacade.CLICK_EVENT,
                                 { target: n, mouseX: evt.stageX, mouseY: evt.stageY });
    
                if (_shiftDown) {
                    // If SHIFT key is pressed, the clicked node is added to the selection group or
                    // removed from it, if already selected:
                    if (n.props.$selected)
                        sendNotification(ApplicationFacade.DESELECT, [n]);
                    else
                        sendNotification(ApplicationFacade.SELECT, [n]);
                } else {
                    // Clear any previous selection and select only the clicked node:
                    sendNotification(ApplicationFacade.DESELECT_ALL, Groups.NONE);
                    sendNotification(ApplicationFacade.SELECT, [n]);
                }
            }
        }
        
        private function onDoubleClickNode(evt:MouseEvent):void { trace("** 2-CLICK [node]");
            if (!_ctrlDown) {
                var n:NodeSprite = evt.target as NodeSprite;
                sendNotification(ApplicationFacade.DOUBLE_CLICK_EVENT,
                                 { target: n, mouseX: evt.stageX, mouseY: evt.stageY });
            }
            evt.stopImmediatePropagation();
        }
        
        private function onDragNodeStart(evt:DragEvent):void { trace("== START Drag Node");
            _draggingNode = true;
            updateCursor();
            evt.node.removeEventListener(MouseEvent.CLICK, onClickNode);
        }
        
        private function onEndDragNode(evt:DragEvent):void { trace("== END Drag Node");
            _draggingNode = false;
            _draggingGraph = false;
            if (!_ctrlDown || graphProxy.rolledOverNode == null)
                vis.hideDragRectangle();
            updateCursor();
            
            // Fix a bug on Safari when mouse-up occurs out of the Flash area, which ends the
            // dragging action without dispatching a MOUSE_UP event before:
            if (evt.node.hasEventListener(MouseEvent.MOUSE_UP)) {
                evt.node.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP));
            }
        }
        
        private function onDragNode(evt:DragEvent):void {
            var target:NodeSprite = evt.node;
            var nodes:*;

            if (_ctrlDown) {
                _draggingGraph = true;
                var data:Data = vis.getDisconnectedData(target);
                nodes = data.nodes;
            } else if (target.props.$selected) {
	            // Drag the other selected nodes as well:
	            nodes = graphProxy.selectedNodes;
            } else {
                nodes = [target];
            }
            
            updateCursor();
            
            for each (var n:NodeSprite in nodes) {
                if (n != target) {
                    n.x += evt.amountX;
                    n.y += evt.amountY;
                }
                // Move node labels as well, bacause they have "LAYER" policy:
                // It is faster than labeler.operate() or vis.update()!
                if (configProxy.nodeLabelsVisible && n.props.label) {
                    n.props.label.x += evt.amountX;
                    n.props.label.y += evt.amountY;
                }
            }
            
            if (Utils.isLinux()) {
                DirtySprite.renderDirty();
                if (configProxy.edgeLabelsVisible) graphView.updateLabels(Groups.EDGES);
            }
            
            vis.updateDragRectangle(evt.amountX, evt.amountY);
        }
        
        private function onSelect(evt:SelectionEvent):void {
            if (evt.items != null && evt.items.length > 0)
                sendNotification(ApplicationFacade.SELECT, evt.items);
        }
        
        private function onDeselect(evt:SelectionEvent):void {
            if (evt.items != null && evt.items.length > 0)
                sendNotification(ApplicationFacade.DESELECT, evt.items);
        }
        
        // EDGE listener functions:
        // -----------------------------------------------------------------------------------------
        private function onRollOverEdge(evt:MouseEvent):void {
            evt.stopImmediatePropagation();
            var e:EdgeSprite = evt.target as EdgeSprite;
            sendNotification(ApplicationFacade.ROLLOVER_EVENT, e);
            updateCursor();
        }
        
        private function onRollOutEdge(evt:MouseEvent):void {
            evt.stopImmediatePropagation();
            var e:EdgeSprite = evt.target as EdgeSprite;
            sendNotification(ApplicationFacade.ROLLOUT_EVENT, e);
            updateCursor();
        }
        
        private function onMouseDownEdge(evt:MouseEvent):void { trace("** Mouse DOWN [edge]");
            if (!_draggingGraph && !_ctrlDown) {
                var e:EdgeSprite = evt.target as EdgeSprite;
                e.addEventListener(MouseEvent.CLICK, onClickEdge, false, 0, true);
                // Remove the SELECTION CONTROL:
                selectionControl.detach();
            }
        }
        
        private function onClickEdge(evt:MouseEvent):void { trace("** Click [edge]");
            evt.currentTarget.removeEventListener(evt.type, arguments.callee);
            
            if (!_draggingGraph && !_ctrlDown) {
                var edge:EdgeSprite = evt.target as EdgeSprite;
                if (edge == null) return;
                
                sendNotification(ApplicationFacade.CLICK_EVENT,
                                 { target: edge, mouseX: evt.stageX, mouseY: evt.stageY });
                var edgesList:Array = [edge];
    
                if (_shiftDown) {
                    // If SHIFT key is pressed, the clicked edge is added to the selection group or
                    // removed from it, if already selected:
                    if (edge.props.$selected)
                        sendNotification(ApplicationFacade.DESELECT, edgesList);
                    else
                        sendNotification(ApplicationFacade.SELECT, edgesList);
                } else {
                    // Clear any previous selection and select only the clicked edge:
                    sendNotification(ApplicationFacade.DESELECT_ALL, Groups.NONE);
                    sendNotification(ApplicationFacade.SELECT, edgesList);
                }
            }
            
            graphView.removeEventListener(MouseEvent.MOUSE_MOVE, onDragSelectionStart);
            evt.stopImmediatePropagation();
        }
        
        private function onDoubleClickEdge(evt:MouseEvent):void { trace("** 2-CLICK [edge] : " + evt.target);
            if (!_ctrlDown) {
                var e:EdgeSprite = evt.target as EdgeSprite;
                sendNotification(ApplicationFacade.DOUBLE_CLICK_EVENT,
                                 { target: e, mouseX: evt.stageX, mouseY: evt.stageY });
            }
            graphView.removeEventListener(MouseEvent.MOUSE_MOVE, onDragSelectionStart);
            evt.stopImmediatePropagation();
        }
        
        // OTHER functions:
        // -----------------------------------------------------------------------------------------
        
        private function rescaleNodeLabel(n:NodeSprite, reset:Boolean=false):void {
            if (n != null && configProxy.config.nodeLabelsVisible) {
                var label:TextSprite = n.props.label as TextSprite;
                if (label != null) {
                    var fsize:Number = configProxy.visualStyle.getValue(VisualProperties.NODE_LABEL_FONT_SIZE, n.data) as Number;
                    if (reset)
                        label.size = fsize;
                    else if (_graphScale < 1)
                        label.size = fsize / _graphScale;
                    
                    vis.nodeLabeler.operate();
                }
            }
        }
        
        private function setStyleToSelectionControl(style:VisualStyleVO):void {
        	if (_selectionControl == null) return;
        	
            _selectionControl.fillColor = 0x8888ff;
            _selectionControl.fillAlpha = 0.2;
            _selectionControl.lineColor = 0x8888ff;
            _selectionControl.lineAlpha = 0.4;
            _selectionControl.lineWidth = 2;
            
            // Set visual properties according to current style:
            if (style.hasVisualProperty(VisualProperties.SELECTION_FILL_COLOR))
                _selectionControl.fillColor = style.getDefaultValue(VisualProperties.SELECTION_FILL_COLOR) as uint;
            if (style.hasVisualProperty(VisualProperties.SELECTION_FILL_ALPHA))
                _selectionControl.fillAlpha = style.getDefaultValue(VisualProperties.SELECTION_FILL_ALPHA) as Number;
            if (style.hasVisualProperty(VisualProperties.SELECTION_LINE_COLOR))
                _selectionControl.lineColor = style.getDefaultValue(VisualProperties.SELECTION_LINE_COLOR) as uint;
            if (style.hasVisualProperty(VisualProperties.SELECTION_LINE_ALPHA))
                _selectionControl.lineAlpha = style.getDefaultValue(VisualProperties.SELECTION_LINE_ALPHA) as Number;
            if (style.hasVisualProperty(VisualProperties.SELECTION_LINE_WIDTH))
                _selectionControl.lineWidth = style.getDefaultValue(VisualProperties.SELECTION_LINE_WIDTH) as Number;
        }
        
        private function disposeDataSprite(ds:DataSprite):void {
            // Force a roll-out, to keep things in a good state:
            ds.dispatchEvent(new MouseEvent(MouseEvent.ROLL_OUT));
            
            // Remove event listeners:
            if (ds is NodeSprite) {
                ds.removeEventListener(MouseEvent.ROLL_OVER, onRollOverNode);
                ds.removeEventListener(MouseEvent.ROLL_OUT, onRollOutNode);
                ds.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDownNode);
                ds.removeEventListener(MouseEvent.MOUSE_UP, onMouseUpNode);
                ds.removeEventListener(MouseEvent.CLICK, onClickNode);
                ds.removeEventListener(MouseEvent.DOUBLE_CLICK, onDoubleClickNode);
                
                // Delete its label:
                if (ds.props.label != null) {
                    vis.labels.removeChild(ds.props.label);
                    ds.props.label = null;
                }
            } else if (ds is EdgeSprite) {
                ds.removeEventListener(MouseEvent.ROLL_OVER, onRollOverEdge);
                ds.removeEventListener(MouseEvent.ROLL_OUT, onRollOutEdge);
                ds.removeEventListener(MouseEvent.MOUSE_DOWN, onMouseDownEdge);
                ds.removeEventListener(MouseEvent.CLICK, onClickEdge);
                ds.removeEventListener(MouseEvent.DOUBLE_CLICK, onDoubleClickEdge);
            }
            
            // Avoinding errors in case the tooltip is about to be shown:
            ds.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_OUT, true, false, 0, 0, vis));
        }
        
        private function updateCursor():void {
            // TODO: send separate notifications for "rollover", "drag_start", etc,
            // instead of asking to update the cursor.
            sendNotification(ApplicationFacade.UPDATE_CURSOR, { selecting: _selecting,
                                                                draggingNode: _draggingNode,
                                                                draggingGraph: _draggingGraph,
                                                                shiftDown: _shiftDown,
                                                                ctrlDown: _ctrlDown });
        }
    }
}
