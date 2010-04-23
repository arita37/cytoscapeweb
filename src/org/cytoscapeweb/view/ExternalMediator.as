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
    import com.adobe.serialization.json.JSON;
    
    import flash.external.ExternalInterface;
    import flash.utils.ByteArray;
    
    import mx.utils.Base64Encoder;
    
    import org.cytoscapeweb.ApplicationFacade;
    import org.cytoscapeweb.model.data.FirstNeighborsVO;
    import org.cytoscapeweb.model.data.VisualStyleBypassVO;
    import org.cytoscapeweb.model.data.VisualStyleVO;
    import org.cytoscapeweb.model.methods.error;
    import org.cytoscapeweb.util.ExternalFunctions;
    import org.cytoscapeweb.util.GraphUtils;
    import org.cytoscapeweb.util.Groups;
    import org.puremvc.as3.interfaces.INotification;
        
    /**
     * This mediator encapsulates the interaction with the JavaScript API.
     */
    public class ExternalMediator extends BaseMediator {

        // ========[ CONSTANTS ]====================================================================

        /** Cannonical name of the Mediator. */
        public static const NAME:String = "ExternalInterfaceMediator";
        
        // ========[ PRIVATE PROPERTIES ]===========================================================
        

        // ========[ CONSTRUCTOR ]==================================================================
   
        public function ExternalMediator(viewComponent:Object) {
            super(NAME, viewComponent, this);
        }

        // ========[ PUBLIC METHODS ]===============================================================
    
        /** @inheritDoc */
        override public function getMediatorName():String {
            return NAME;
        }
        
        /** @inheritDoc */
        override public function listNotificationInterests():Array {
            return [ApplicationFacade.ADD_CALLBACKS, ApplicationFacade.CALL_EXTERNAL_INTERFACE];
        }

        /** @inheritDoc */
        override public function handleNotification(n:INotification):void {
            switch (n.getName()) {
                case ApplicationFacade.ADD_CALLBACKS:
                    addCallbacks();
                    break;
                case ApplicationFacade.CALL_EXTERNAL_INTERFACE:
                    var options:Object = n.getBody();
                    var json:Boolean = ExternalFunctions.isJSON(options.functionName);
                    callExternalInterface(options.functionName, options.argument, json);
                    break;
            }
        }
        
        public function hasListener(type:String, group:String=Groups.NONE):Boolean {
            return callExternalInterface(ExternalFunctions.HAS_LISTENER, {type: type, group: group});
        }
        
        /**
         * Call a JavaScript function.
         * 
         * @param functionName The name of the JavaScript function.
         * @param argument The argument value.
         * @param json Whether or not the argument must be converted to the JSON format before
         *             the function is invoked.<br />
         *             Its important to convert nodes and edges data to JSON before calling JS functions
         *             from ActionScript, so graph attribute names can accept special characters such as:<br />
         *             <code>. - + * / \ :</code><br />
         *             Cytoscape usually creates attribute names such as "node.fillColor" or "vizmap:EDGE_COLOR"
         *             when exporting to XGMML, and those special characters crash the JS callback functions,
         *             because, apparently, Flash cannot call JS functions with argument objects that have
         *             one or more attribute names with those characters.
         * @return The return of the JavaScript function or <code>undefined</code> if the external
         *         function returns void.
         */
        public function callExternalInterface(functionName:String, argument:*, json:Boolean=false):* {
            if (ExternalInterface.available) {
                var desigFunction:String;
                
                if (json && argument != null) {
                    argument = JSON.encode(argument);
                    // Call a proxy function instead, sending the name of the designated function.
                    desigFunction = functionName;
                    functionName = ExternalFunctions.DISPATCH;
                }
                
                functionName = "_cytoscapeWebInstances." + configProxy.id + "." + functionName;
                try {
                    if (desigFunction != null)
                        return ExternalInterface.call(functionName, desigFunction, argument);
                    else
                        return ExternalInterface.call(functionName, argument);
                } catch (err:Error) {
                    error(err.message, err.errorID, err.name, err.getStackTrace());
                }
            } else {
                trace("Error [callExternalInterface]: ExternalInterface is NOT available!");
                return undefined;
            }
        }
        
        // ========[ PRIVATE METHODS ]==============================================================
        
        // Callbacks ---------------------------------------------------
        
        private function draw(options:Object):void {
            sendNotification(ApplicationFacade.DRAW_GRAPH, options);
        }
        
        private function addContextMenuItem(label:String, group:String=null):void {
            if (group == null) group = Groups.NONE;
            menuProxy.addMenuItem(label, group);
        }
        
        private function removeContextMenuItem(label:String, group:String=null):void {
            if (group == null) group = Groups.NONE;
            menuProxy.removeMenuItem(label, group);
        }
        
        private function select(group:String, items:Array):void {
            if (items == null)
                sendNotification(ApplicationFacade.SELECT_ALL, group);
            else
                sendNotification(ApplicationFacade.SELECT, graphProxy.getDataSpriteList(items, group));
        }
        
        private function deselect(group:String, items:Array):void {
            if (items == null)
                sendNotification(ApplicationFacade.DESELECT_ALL, group);
            else
                sendNotification(ApplicationFacade.DESELECT, graphProxy.getDataSpriteList(items, group));
        }
       
        private function mergeEdges(value:Boolean):void {
            sendNotification(ApplicationFacade.MERGE_EDGES, value);
        }
        
        private function isEdgesMerged():Boolean {
            return graphProxy.edgesMerged;
        }
        
        private function showPanZoomControl(value:Boolean):void {
            sendNotification(ApplicationFacade.SHOW_PANZOOM_CONTROL, value);
        }
        
        private function showNodeLabels(value:Boolean):void {
            sendNotification(ApplicationFacade.SHOW_LABELS, { value: value, group: Groups.NODES });
        }
        
        private function isNodeLabelsVisible():Boolean {
            return configProxy.nodeLabelsVisible;
        }
        
        private function showEdgeLabels(value:Boolean):void {
            sendNotification(ApplicationFacade.SHOW_LABELS, { value: value, group: Groups.EDGES });
        }
        
        private function isEdgeLabelsVisible():Boolean {
            return configProxy.edgeLabelsVisible;
        }
        
        private function enableNodeTooltips(val:Boolean):void {
            configProxy.nodeTooltipsEnabled = val;
        }
        
        private function isNodeTooltipsEnabled():Boolean {
            return configProxy.nodeTooltipsEnabled;
        }
        
        private function enableEdgeTooltips(value:Boolean):void {
            configProxy.edgeTooltipsEnabled = value;
        }
        
        private function isEdgeTooltipsEnabled():Boolean {
            return configProxy.edgeTooltipsEnabled;
        }
        
        private function isPanZoomControlVisible():Boolean {
            return configProxy.panZoomControlVisible;
        }

        private function enableCustomCursor(value:Boolean):void {
            sendNotification(ApplicationFacade.ENABLE_CUSTOM_CURSORS, value);
        }

        private function enableGrabToPan(value:Boolean):void {
            sendNotification(ApplicationFacade.ENABLE_GRAB_TO_PAN, value);
        }
        
        private function isGrabToPanEnabled():Boolean {
            return configProxy.grabToPanEnabled;
        }
        
        private function panBy(panX:Number, panY:Number):void {
            sendNotification(ApplicationFacade.PAN_GRAPH, {panX: panX, panY: panY});
        }
        
        private function panToCenter():void {
            sendNotification(ApplicationFacade.CENTER_GRAPH);
        }
        
        private function zoomTo(scale:Number):void {
            sendNotification(ApplicationFacade.ZOOM_GRAPH, scale);
        }
        
        private function zoomToFit():void {
            sendNotification(ApplicationFacade.ZOOM_GRAPH_TO_FIT);
        }
        
        private function getZoom():Number {
            return graphProxy.zoom;
        }
        
        private function filter(group:String, items:Array, updateVisualMappers:Boolean=false):void {
            var filtered:Array = graphProxy.getDataSpriteList(items, group);
            sendNotification(ApplicationFacade.FILTER, 
                             { group: group, filtered: filtered, updateVisualMappers: updateVisualMappers });
        }
        
        private function removeFilter(group:String, updateVisualMappers:Boolean=false):void {
            sendNotification(ApplicationFacade.REMOVE_FILTER, 
                             { group: group, updateVisualMappers: updateVisualMappers });
        }
        
        private function firstNeighbors(rootNodes:Array, ignoreFilteredOut:Boolean=false):Object {
            var obj:Object = {};
            
            if (rootNodes != null && rootNodes.length > 0) {
                var nodes:Array = graphProxy.getDataSpriteList(rootNodes, Groups.NODES);
                
                if (nodes != null && nodes.length > 0) {
                    var fn:FirstNeighborsVO  = new FirstNeighborsVO(nodes, ignoreFilteredOut);
                    obj = fn.toObject();
                    obj = JSON.encode(obj);
                }
            }
            
            return obj;
        }

        private function getNodes():String {
            var arr:Array = GraphUtils.toExtObjectsArray(graphProxy.graphData.nodes);
            return JSON.encode(arr);
        }
        
        private function getEdges():String {
            var edges:Array = graphProxy.edges;
            var arr:Array = GraphUtils.toExtObjectsArray(edges);
            return JSON.encode(arr);
        }
        
        private function getMergedEdges():String {
            var edges:Array = graphProxy.mergedEdges;
            var arr:Array = GraphUtils.toExtObjectsArray(edges);
            return JSON.encode(arr);
        }
        
        private function getSelectedNodes():String {
            var arr:Array = GraphUtils.toExtObjectsArray(graphProxy.selectedNodes);
            return JSON.encode(arr);
        }
        
        private function getSelectedEdges():String {
            var arr:Array = GraphUtils.toExtObjectsArray(graphProxy.selectedEdges);
            return JSON.encode(arr);
        }
        
        private function getLayout():String {
            return configProxy.currentLayout;
        }
        
        private function setVisualStyle(style:Object):void {
            if (style != null) {
                var vo:VisualStyleVO = VisualStyleVO.fromObject(style);
                sendNotification(ApplicationFacade.SET_VISUAL_STYLE, vo);
            }
        }
        
        private function getVisualStyle():Object {
            return configProxy.visualStyle.toObject();
        }
        
        private function setVisualStyleBypass(obj:/*{group->{id->{propName->value}}}*/Object):void {
            var bypass:VisualStyleBypassVO = VisualStyleBypassVO.fromObject(obj);
            sendNotification(ApplicationFacade.SET_VISUAL_STYLE_BYPASS, bypass);
        }
        
        private function getVisualStyleBypass():Object {
            return configProxy.visualStyleBypass.toObject();
        }
        
        private function applyLayout(name:String):void {
            sendNotification(ApplicationFacade.APPLY_LAYOUT, name);
        }
        
        private function addNode(x:Number, y:Number, data:Object, updateVisualMappers:Boolean=false):void {
            sendNotification(ApplicationFacade.ADD_NODE,
                             { x: x, y: y, data: data, updateVisualMappers: updateVisualMappers });
// TODO: how to return the new node?
        }
        
        private function addEdge(data:Object, updateVisualMappers:Boolean=false):void {
            sendNotification(ApplicationFacade.ADD_EDGE,
                             { data: data, updateVisualMappers: updateVisualMappers });
// TODO: how to return the new edge?
        }
        
        private function removeItems(group:String=Groups.NONE,
                                     items:Array=null, 
                                     updateVisualMappers:Boolean=false):void {
            sendNotification(ApplicationFacade.REMOVE_ITEMS,
                             { group: group, items: items, updateVisualMappers: updateVisualMappers });
        }
        
        private function addDataField(group:String, dataField:Object):void {
            sendNotification(ApplicationFacade.ADD_DATA_FIELD, { group: group, dataField: dataField });
        }
        
        private function removeDataField(group:String, name:String):void {
            sendNotification(ApplicationFacade.REMOVE_DATA_FIELD, { group: group, name: name });
        }
        
        private function updateData(group:String, items:Array=null, data:Object=null):void {
            if (items != null || data != null)
                sendNotification(ApplicationFacade.UPDATE_DATA, { group: group, items: items, data: data });
        }
        
        private function getNetworkAsText(format:String="xgmml", options:Object=null):String {
            return graphProxy.getDataAsText(format, options);
        }
        
        private function getNetworkAsImage(format:String="pdf", options:Object=null):String {
            if (options == null) options = {};
            // TODO: Refactor - proxy should NOT use a mediator!!!
            var appMediator:ApplicationMediator = facade.retrieveMediator(ApplicationMediator.NAME) as ApplicationMediator;
            var ba:ByteArray = appMediator.getGraphImage(format, options.width, options.height);
            
            var encoder:Base64Encoder = new Base64Encoder();
            encoder.encodeBytes(ba);

            return encoder.toString();
        }
        
        private function exportNetwork(format:String, url:String, options:Object=null):void {
            sendNotification(ApplicationFacade.EXPORT_NETWORK, { format: format, url: url, options: options });
        }

        // ------------------------------------------------------------
        
        private function addCallbacks():void {
            if (ExternalInterface.available) {
                ExternalInterface.marshallExceptions = true;
                
                var functions:Array = [ "draw",
                                        "addContextMenuItem", "removeContextMenuItem", 
                                        "select", "deselect", 
                                        "mergeEdges", "isEdgesMerged", 
                                        "showNodeLabels", "isNodeLabelsVisible", 
                                        "showEdgeLabels", "isEdgeLabelsVisible", 
                                        "enableNodeTooltips", "isNodeTooltipsEnabled", 
                                        "enableEdgeTooltips", "isEdgeTooltipsEnabled", 
                                        "showPanZoomControl", "isPanZoomControlVisible",
                                        "enableCustomCursor", 
                                        "enableGrabToPan", "isGrabToPanEnabled", "panBy", "panToCenter", 
                                        "zoomTo", "zoomToFit", "getZoom", 
                                        "filter", "removeFilter", 
                                        "firstNeighbors", 
                                        "getNodes", "getEdges", "getMergedEdges", 
                                        "getSelectedNodes", "getSelectedEdges", 
                                        "getLayout", "applyLayout", 
                                        "setVisualStyle", "getVisualStyle", 
                                        "getVisualStyleBypass", "setVisualStyleBypass",
                                        "addNode", "addEdge", "removeItems",
                                        "addDataField", "removeDataField", "updateData",
                                        "getNetworkAsText", "getNetworkAsImage", 
                                        "exportNetwork" ];

                for each (var f:String in functions) addFunction(f);

            } else {
                sendNotification(ApplicationFacade.EXT_INTERFACE_NOT_AVAILABLE);
            }
        }
        
        private function addFunction(name:String):void {
            try {
                ExternalInterface.addCallback(name, this[name]);
            } catch(err:Error) {
                trace("Error [addFunction]: " + err);
                // TODO: decide what to do with this:
                sendNotification(ApplicationFacade.ADD_CALLBACK_ERROR, err);
            }
        }
    }
}