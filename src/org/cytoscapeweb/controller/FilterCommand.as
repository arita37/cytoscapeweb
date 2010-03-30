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
package org.cytoscapeweb.controller {
    import flare.vis.data.DataSprite;
    import flare.vis.data.NodeSprite;
    
    import org.cytoscapeweb.ApplicationFacade;
    import org.cytoscapeweb.model.ConfigProxy;
    import org.cytoscapeweb.model.ExternalInterfaceProxy;
    import org.cytoscapeweb.model.GraphProxy;
    import org.cytoscapeweb.util.ExternalFunctions;
    import org.cytoscapeweb.util.GraphUtils;
    import org.cytoscapeweb.util.Groups;
    import org.cytoscapeweb.view.GraphMediator;
    import org.puremvc.as3.interfaces.INotification;
    import org.puremvc.as3.patterns.command.SimpleCommand;
    

    public class FilterCommand extends SimpleCommand {
        
        override public function execute(notification:INotification):void {
            var gr:String = notification.getBody().group;
            var arr:Array = notification.getBody().filtered;
            var updateVisualMappers:Boolean = notification.getBody().updateVisualMappers;

            if (arr != null) {
                var nodes:Array = gr === Groups.NODES || gr === Groups.NONE ? [] : null;
                var edges:Array = gr === Groups.EDGES || gr === Groups.NONE ? [] : null;
                
                // Separate nodes and edges:
                for each (var ds:DataSprite in arr) {
                    if (ds is NodeSprite && nodes != null)
                        nodes.push(ds);
                    else if (edges != null)
                        edges.push(ds);
                }
                
                if (nodes != null || edges != null) {
                    // Update the model:
                    var graphProxy:GraphProxy = facade.retrieveProxy(GraphProxy.NAME) as GraphProxy;
                    var groups:Array = [Groups.NONE];
                    
                    if (edges != null) {
                        graphProxy.filteredEdges = edges;
                        groups.push(Groups.EDGES);
                    }
                    if (nodes != null) {
                        graphProxy.filteredNodes = nodes;
                        groups.push(Groups.NODES);
                    }

                    if (updateVisualMappers) {
                        var cfgProxy:ConfigProxy = facade.retrieveProxy(ConfigProxy.NAME) as ConfigProxy;
                        cfgProxy.bindGraphData(graphProxy.graphData);
                    }
                        
                    // Update the view:
                    var mediator:GraphMediator = facade.retrieveMediator(GraphMediator.NAME) as GraphMediator;
                    mediator.updateFilters(nodes, edges, updateVisualMappers);
            
                    // Call external listeners:
                    var extProxy:ExternalInterfaceProxy = facade.retrieveProxy(ExternalInterfaceProxy.NAME) as ExternalInterfaceProxy;
                    var objs:Array, body:Object, type:String = "filter";
                
                    if (nodes != null && extProxy.hasListener(type, Groups.NODES)) {
                        objs = GraphUtils.toExtObjectsArray(nodes);
                        body = { functionName: ExternalFunctions.INVOKE_LISTENERS, 
                                 argument: { type: type, group: Groups.NODES, target: objs } };
                        
                        sendNotification(ApplicationFacade.CALL_EXTERNAL_INTERFACE, body);
                    }
                    
                    if (edges != null && extProxy.hasListener(type, Groups.EDGES)) {
                        objs = GraphUtils.toExtObjectsArray(edges);
                        body = { functionName: ExternalFunctions.INVOKE_LISTENERS, 
                                 argument: { type: type, group: Groups.EDGES, target: objs } };
    
                        sendNotification(ApplicationFacade.CALL_EXTERNAL_INTERFACE, body);
                    }
                    
                    if ((nodes != null || edges != null) && extProxy.hasListener(type, Groups.NONE)) {
                        objs = GraphUtils.toExtObjectsArray(arr);
                        body = { functionName: ExternalFunctions.INVOKE_LISTENERS, 
                                 argument: { type: type, group: Groups.NONE, target: objs } };
    
                        sendNotification(ApplicationFacade.CALL_EXTERNAL_INTERFACE, body);
                    }
                }
            }
        }
    }
}