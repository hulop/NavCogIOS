/*******************************************************************************
 * Copyright (c) 2014, 2015  IBM Corporation, Carnegie Mellon University and others
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 *
 * Contributors:
 *  Chengxiong Ruan (CMU) - initial API and implementation
 *  IBM Corporation - initial API and implementation
 *******************************************************************************/
 
var _blueDot = null;
var _redDot = null;

var _currentLayer = null;
var _layers = null;
var _map = null;
var _regionOverlays = [];
//var _data = null; // redundant
var _startNode = null;

function loaded() {
	_map = getNewGoogleMap();
}

function setMapData(newData) { // newData is layers object
    _layers = newData;
    //_data = newData;
    //_layers = _data.layers;
}

function setStartNode(lat, lng) {
    _startNode = newNodeWithLatLng(lat, lng);
    updateBlueDot(_startNode);
}


function startNavigation(path, layerID) {
    for(var i = 0; i < path.length-1; i++) {
        if (path[i].layer == path[i+1].layer) {
            addALineToLayer(path[i].layer, path[i], path[i+1]);
        }
    }
    renderLayerWithID(layerID);
}

/*
function startNavigation(pathNodeIds) {
	var layerID = getLayerIDForNodeWitID(pathNodeIds[0]);
    addALineToLayerFromStartNode(layerID, pathNodeIds[0]);
	for (var i = 1; i < pathNodeIds.length; i++) {
		var curLayerId = getLayerIDForNodeWitID(pathNodeIds[i]);
		if (curLayerId != layerID) {
			layerID = curLayerId;
		} else {
			addALineToLayer(layerID, pathNodeIds[i - 1], pathNodeIds[i]);
		}
	};
	layerID = getLayerIDForNodeWitID(pathNodeIds[0]);
	renderLayerWithID(layerID);
}
*/

function updateBlueDot(latLng) {
	if (_blueDot == null) {
		var image = {
	    	size: new google.maps.Size(25, 25),
	    	anchor: new google.maps.Point(12.5, 12.5),
	    	url: "./img/round-blue.png"
	    };
	    _blueDot = new google.maps.Marker({
	    	map : _map,
	    	position: new google.maps.LatLng(latLng.lat, latLng.lng),
	    	icon: image,
	    	shape: {
				coords: [12.5, 12.5, 20],
				type: "circle",
			},
	    });
	} else {
        _blueDot.setMap(null);
        _blueDot.setMap(_map);
		_blueDot.setPosition(latLng);
	}
	_map.setCenter(latLng);
}

function updateRedDot(latLng) {
    if (!latLng) {
        if (_redDot) {
            _redDot.setMap(null);
        }
        return;
    }
    if (_redDot == null) {
        var image = {
        scaledSize: new google.maps.Size(12.5, 12.5),
        anchor: new google.maps.Point(6.25, 6.25),
        url: "./img/round-red.png"
        };
        _redDot = new google.maps.Marker({
                                         map : _map,
                                         position: new google.maps.LatLng(latLng.lat, latLng.lng),
                                         icon: image,
                                         shape: {
                                         coords: [6.25, 6.25, 10],
                                         type: "circle"
                                         },
                                         });
    } else {
        _redDot.setMap(_map);
        _redDot.setPosition(latLng);
    }
    _map.setCenter(latLng);
}


function stopNavigation() {
	for (var layerID in _layers) {
		for (var line in _layers[layerID].edgeLines) {
			_layers[layerID].edgeLines[line].setMap(null);
		}
		delete (_layers[layerID])["edgeLines"];
	}
	for (var regionOverlay in _regionOverlays) {
		_regionOverlays[regionOverlay].setMap(null);
	}
}

function switchToLayerWithID(layerID) {
	clearMap();
	renderLayerWithID(layerID);
}

function renderLayerWithID(layerID) {
	var layer = _layers[layerID];
	for (var line in layer.edgeLines) {
		layer.edgeLines[line].setMap(_map);
	}
	for (var regionName in layer.regions) {
		var region = layer.regions[regionName];
		renderRegion(region);
	}
}

function clearMap() {
	for (var layerID in _layers) {
		for (var line in _layers[layerID].edgeLines) {
			_layers[layerID].edgeLines[line].setMap(null);
		}
	}
	for (var regionOverlay in _regionOverlays) {
		_regionOverlays[regionOverlay].setMap(null);
	}
}

function addALineToLayer(layerID, node1, node2) {
    var layer = _layers[layerID];
    if (!layer.edgeLines) {
        layer.edgeLines = [];
    };
    var newLine = newLineBetweenNodes(node1, node2);
    layer.edgeLines.push(newLine);
}

/*
function addALineToLayer(layerID, nodeID1, nodeID2) {
	var layer = _layers[layerID];
	if (!layer.edgeLines) {
		layer.edgeLines = [];
	};
	var node1 = layer.nodes[nodeID1];
	var node2 = layer.nodes[nodeID2];
	var newLine = newLineBetweenNodes(node1, node2);
	layer.edgeLines.push(newLine);
}
 */

function addALineToLayerFromStartNode(layerID, nodeID) {
    var layer = _layers[layerID];
    if (!layer.edgeLines) {
        layer.edgeLines = [];
    };
    var node1 = _startNode;
    var node2 = layer.nodes[nodeID];
    var newLine = newLineBetweenNodes(node1, node2);
    layer.edgeLines.push(newLine);
}

function getLayerIDForNodeWitID(nodeID) {
	for (var layerID in _layers) {
		if (_layers[layerID].nodes[nodeID]) {
			return layerID;
		};
	}
}

function getNewGoogleMap() {
	return new google.maps.Map(document.getElementById("google-map-view"), {
		zoom : 19,
		center : {
		    lat : 40.44341980831697,
		    lng : -79.94513064622879
		},
		disableDefaultUI: true,
		styles : [{
			featureType: "poi",
			elementType: "labels",
			stylers : [
				{visibility: "off"}
			]
		}],
		zoomControl: true
    });
}

function newLineBetweenNodes(node1, node2) {
	var path = [];
	path.push({lat:node1.lat, lng:node1.lng});
	path.push({lat:node2.lat, lng:node2.lng});
	var edgeLine = new google.maps.Polyline({
		map: null,
		path: path,
		strokeColor: "#00B4B4",
		strokeWeight: 10,
		strokeOpacity: 1.0
	});
	return edgeLine;
}

function newNodeWithLatLng(lat, lng) {
    return {
        lat: lat,
        lng: lng
    }
}

function renderRegion(region) {
	if (_regionOverlays[region.name]) {
		_regionOverlays[region.name].setMap(_map);
	} else {
		var regionOverlay = new FloorPlanOverlay();
		regionOverlay.setOption({
			src: region.image,
			lat: region.lat,
			lng: region.lng,
			name: region.name,
			ppm: region.ppm,
			width: 1000,
			height: 1000,
			rotate: region.rotate
		});
		regionOverlay.setMap(_map);
		_regionOverlays[region.name] = regionOverlay;
	}
}
