window.toggle_toolbox = function() {
  var c  = "open";
  var tb = document.getElementById('admin_toolbox');
  tb.className = (tb.className==c) ? "" : c;
}

