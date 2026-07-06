var poseData = null;
var dragJoint = -1;
var placeJoint = -1;
var refImage = null;
var skeletonImage = null; // Extracted OpenPose skeleton overlay

// OpenPose 18 keypoint names
var JOINT_NAMES = [
  'nose','neck','right_shoulder','right_elbow','right_wrist',
  'left_shoulder','left_elbow','left_wrist','right_hip','right_knee',
  'right_ankle','left_hip','left_knee','left_ankle','right_eye',
  'left_eye','right_ear','left_ear'
];

// Limb connections [from, to]
var LIMBS = [
  [1,0],[1,2],[1,5],[2,3],[3,4],[5,6],[6,7],
  [1,8],[8,9],[9,10],[1,11],[11,12],[12,13],
  [0,14],[14,16],[0,15],[15,17]
];

// Rainbow colors for keypoints
var KP_COLORS = [
  '#ff0000','#ff5500','#ffaa00','#ffff00','#aaff00',
  '#55ff00','#00ff00','#00ff55','#00ffaa','#00ffff',
  '#00aaff','#0055ff','#0000ff','#5500ff','#aa00ff',
  '#ff00ff','#ff00aa','#ff0055'
];

// Colors for limbs
var LIMB_COLORS = [
  '#000099','#990000','#993300','#996600','#999900',
  '#669900','#339900','#009900','#009933','#009966',
  '#009999','#006699','#003399','#330099','#660099',
  '#990099','#990066'
];

function extractPose() {
  var status = document.getElementById('pose-status');
  status.textContent = 'Extracting pose...';
  fetch('/cuts/' + SLUG + '/extract-pose', { method: 'POST' })
    .then(function(r) { return r.json(); })
    .then(function(data) {
      if (data.error) {
        status.textContent = 'Error: ' + data.error;
        return;
      }
      status.textContent = 'Skeleton extracted! Trace the joints to match.';
      document.getElementById('pose-panel').style.display = 'block';
      // Load the skeleton image as a tracing overlay
      skeletonImage = new Image();
      skeletonImage.onload = function() { drawPose(); };
      skeletonImage.src = '/cuts/' + SLUG + '/pose/skeleton?' + Date.now();
      loadPoseEditor();
    })
    .catch(function(e) {
      status.textContent = 'Error: ' + e.message;
    });
}

// Default standing pose (normalized 0-1 coordinates)
var DEFAULT_POSE = [
  {x:0.50, y:0.12, confidence:1}, // 0  nose
  {x:0.50, y:0.20, confidence:1}, // 1  neck
  {x:0.40, y:0.22, confidence:1}, // 2  right shoulder
  {x:0.35, y:0.35, confidence:1}, // 3  right elbow
  {x:0.32, y:0.48, confidence:1}, // 4  right wrist
  {x:0.60, y:0.22, confidence:1}, // 5  left shoulder
  {x:0.65, y:0.35, confidence:1}, // 6  left elbow
  {x:0.68, y:0.48, confidence:1}, // 7  left wrist
  {x:0.44, y:0.48, confidence:1}, // 8  right hip
  {x:0.43, y:0.65, confidence:1}, // 9  right knee
  {x:0.42, y:0.82, confidence:1}, // 10 right ankle
  {x:0.56, y:0.48, confidence:1}, // 11 left hip
  {x:0.57, y:0.65, confidence:1}, // 12 left knee
  {x:0.58, y:0.82, confidence:1}, // 13 left ankle
  {x:0.47, y:0.10, confidence:1}, // 14 right eye
  {x:0.53, y:0.10, confidence:1}, // 15 left eye
  {x:0.44, y:0.11, confidence:1}, // 16 right ear
  {x:0.56, y:0.11, confidence:1}, // 17 left ear
];

function loadPoseEditor() {
  placeJoint = -1;
  // Try to load saved pose JSON
  fetch('/cuts/' + SLUG + '/pose')
    .then(function(r) {
      if (r.ok) return r.json();
      return null;
    })
    .then(function(data) {
      if (data && data.keypoints && data.keypoints.some(function(k) { return k.confidence > 0; })) {
        poseData = data;
      } else {
        // Use default standing pose
        poseData = { keypoints: DEFAULT_POSE.map(function(k) { return {x:k.x, y:k.y, confidence:k.confidence}; }) };
      }
      // Load reference image as background
      refImage = new Image();
      refImage.crossOrigin = 'anonymous';
      refImage.onload = function() { drawPose(); };
      refImage.src = '/cuts/' + SLUG + '/reference';
      drawPose();
    });
}

function drawPose() {
  var canvas = document.getElementById('pose-canvas');
  if (!canvas) return;
  var ctx = canvas.getContext('2d');
  var w = canvas.width, h = canvas.height;

  // Clear and draw background
  ctx.fillStyle = '#000';
  ctx.fillRect(0, 0, w, h);
  if (skeletonImage && skeletonImage.complete) {
    // Skeleton image (has original + colored skeleton drawn on it)
    ctx.globalAlpha = 0.6;
    ctx.drawImage(skeletonImage, 0, 0, w, h);
    ctx.globalAlpha = 1.0;
  } else if (refImage && refImage.complete) {
    // No skeleton yet, just show dimmed reference
    ctx.globalAlpha = 0.4;
    ctx.drawImage(refImage, 0, 0, w, h);
    ctx.globalAlpha = 1.0;
  }

  if (!poseData) return;
  var kps = poseData.keypoints;

  // Draw limbs
  for (var i = 0; i < LIMBS.length; i++) {
    var a = kps[LIMBS[i][0]], b = kps[LIMBS[i][1]];
    if (a.confidence > 0 && b.confidence > 0) {
      ctx.strokeStyle = LIMB_COLORS[i];
      ctx.lineWidth = 4;
      ctx.beginPath();
      ctx.moveTo(a.x * w, a.y * h);
      ctx.lineTo(b.x * w, b.y * h);
      ctx.stroke();
    }
  }

  // Draw keypoints (active ones solid, disabled ones as dim outlines)
  for (var i = 0; i < kps.length; i++) {
    var px = kps[i].x * w, py = kps[i].y * h;
    if (kps[i].confidence > 0) {
      ctx.fillStyle = KP_COLORS[i];
      ctx.beginPath();
      ctx.arc(px, py, 6, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = '#fff';
      ctx.lineWidth = 1;
      ctx.stroke();
    } else if (kps[i].x > 0 || kps[i].y > 0) {
      // Disabled joint — show as dim ring
      ctx.strokeStyle = 'rgba(255,255,255,0.2)';
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.arc(px, py, 5, 0, Math.PI * 2);
      ctx.stroke();
    }
  }

  // Label the dragged joint
  if (dragJoint >= 0) {
    var dk = kps[dragJoint];
    ctx.fillStyle = '#fff';
    ctx.font = '12px monospace';
    var label = JOINT_NAMES[dragJoint] + (dk.confidence > 0 ? '' : ' (off)');
    ctx.fillText(label, dk.x * w + 10, dk.y * h - 10);
  }

  // Show instructions
  ctx.fillStyle = 'rgba(255,255,255,0.7)';
  ctx.font = '11px sans-serif';
  ctx.fillText('Drag to move. Right-click to toggle on/off.', 8, h - 8);
}

// Mouse interaction for dragging joints
(function() {
  var canvas = document.getElementById('pose-canvas');
  if (!canvas) return;

  // Prevent context menu on canvas
  canvas.addEventListener('contextmenu', function(e) { e.preventDefault(); });

  canvas.addEventListener('mousedown', function(e) {
    if (!poseData) return;
    var rect = canvas.getBoundingClientRect();
    var mx = (e.clientX - rect.left) / rect.width;
    var my = (e.clientY - rect.top) / rect.height;

    // Find closest keypoint (active or inactive)
    var best = -1, bestDist = 0.04;
    for (var i = 0; i < poseData.keypoints.length; i++) {
      var kp = poseData.keypoints[i];
      var d = Math.sqrt(Math.pow(kp.x - mx, 2) + Math.pow(kp.y - my, 2));
      if (d < bestDist) { bestDist = d; best = i; }
    }

    if (e.button === 2 && best >= 0) {
      // Right-click: toggle joint on/off
      var kp = poseData.keypoints[best];
      kp.confidence = kp.confidence > 0 ? 0 : 1;
      drawPose();
      return;
    }

    // Left-click: start drag (only active joints)
    if (best >= 0 && poseData.keypoints[best].confidence > 0) {
      dragJoint = best;
    } else {
      dragJoint = -1;
    }
  });

  canvas.addEventListener('mousemove', function(e) {
    if (dragJoint < 0 || !poseData) return;
    var rect = canvas.getBoundingClientRect();
    poseData.keypoints[dragJoint].x = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
    poseData.keypoints[dragJoint].y = Math.max(0, Math.min(1, (e.clientY - rect.top) / rect.height));
    drawPose();
  });

  canvas.addEventListener('mouseup', function() { dragJoint = -1; drawPose(); });
  canvas.addEventListener('mouseleave', function() { dragJoint = -1; drawPose(); });
})();

function savePose() {
  if (!poseData) return;
  var status = document.getElementById('pose-save-status');
  status.textContent = 'Saving...';
  fetch('/cuts/' + SLUG + '/pose', {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(poseData)
  })
    .then(function(r) { return r.json(); })
    .then(function(data) {
      status.textContent = data.status === 'ok' ? 'Saved!' : 'Error: ' + data.error;
    });
}

function resetPose() {
  // Reset to default standing pose
  poseData = { keypoints: DEFAULT_POSE.map(function(k) { return {x:k.x, y:k.y, confidence:k.confidence}; }) };
  drawPose();
  document.getElementById('pose-save-status').textContent = 'Reset to default.';
}

function revertPose() {
  // Reload last saved pose
  loadPoseEditor();
  document.getElementById('pose-save-status').textContent = 'Reverted to saved.';
}

function saveAndRender() {
  var textarea = document.querySelector('.script-editor');
  var body = new URLSearchParams();
  body.append('script_content', textarea.value);
  fetch('/cuts/' + SLUG + '/script', { method: 'PUT', body: body })
    .then(function(r) { document.getElementById('render-form').submit(); });
}

// Auto-show pose panel if pose data or skeleton exists
(function() {
  // Try loading skeleton image for overlay
  var skel = new Image();
  skel.onload = function() { skeletonImage = skel; if (poseData) drawPose(); };
  skel.src = '/cuts/' + SLUG + '/pose/skeleton';

  // Check for saved pose JSON
  fetch('/cuts/' + SLUG + '/pose')
    .then(function(r) {
      if (r.ok) {
        document.getElementById('pose-panel').style.display = 'block';
        loadPoseEditor();
      } else if (skeletonImage) {
        document.getElementById('pose-panel').style.display = 'block';
        loadPoseEditor();
      }
    });
})();
