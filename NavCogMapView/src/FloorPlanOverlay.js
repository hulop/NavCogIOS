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
 *******************************************************************************/
 
function FloorPlanOverlay(options) {
    this.setOption(options);
    this.dom = null;
}

FloorPlanOverlay.prototype = new google.maps.OverlayView();

FloorPlanOverlay.prototype.setOption = function(options) {
    if (options) {
    	for(var key in options) {
    	    this[key] = options[key];
    	}
    }
}

FloorPlanOverlay.prototype.onAdd = function() {
    var div = document.createElement('div');
    div.style.borderStyle = 'none';
    div.style.borderWidth = '0px';
    div.style.position = 'absolute';
    
    var img = document.createElement('img');
    img.style.width = '100%';
    img.style.position = 'absolute';
    img.style.opacity = this.opacity || 1.0;
    img.src = this.src;

    div.appendChild(img);    
    this.dom = div;
    
    var panes = this.getPanes();
    panes.overlayLayer.appendChild(div);
};

FloorPlanOverlay.prototype.draw = function() {
    var center = new google.maps.LatLng(this.lat, this.lng);
    var width = this.width / this.ppm;
    var height = this.height / this.ppm;
    
    var len = Math.sqrt(Math.pow(width/2,2)+Math.pow(height/2,2));
    var dne = Math.atan2(+width/2, +height/2);
    var dsw = Math.atan2(-width/2, -height/2);
    var ne = google.maps.geometry.spherical.computeOffset(center, len, dne*180/Math.PI);
    var sw = google.maps.geometry.spherical.computeOffset(center, len, dsw*180/Math.PI);
    
    var prj = this.getProjection();
    sw = prj.fromLatLngToDivPixel(sw);
    ne = prj.fromLatLngToDivPixel(ne);

    var div = this.dom;
    div.style.left = sw.x + 'px';
    div.style.top = ne.y + 'px';
    div.style.width = (ne.x - sw.x) + 'px';
    div.style.height = (sw.y - ne.y) + 'px';

    div.style.webkitTransform = "rotate("+this.rotate+"deg)";
    div.style.oTransform = "rotate("+this.rotate+"deg)";
    div.style.transform = "rotate("+this.rotate+"deg)";
};

FloorPlanOverlay.prototype.move = function(options) {
    var center = new google.maps.LatLng(this.lat, this.lng);
    center = google.maps.geometry.spherical.computeOffset(center, options.length, options.direction);
    this.lat = center.lat();
    this.lng = center.lng();
    return center;
}

FloorPlanOverlay.prototype.onRemove = function() {
    this.dom.parentNode.removeChild(this.dom);
    this.dom = null;
};

FloorPlanOverlay.prototype.setMap = (function(_super) {
    return function(map) {
	   return _super.call(this, map?map:null);
    }
})(FloorPlanOverlay.prototype.setMap);