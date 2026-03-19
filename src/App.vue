<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'

// 状态
const videoRef = ref<HTMLVideoElement | null>(null)
const canvasRef = ref<HTMLCanvasElement | null>(null)
const threeCanvasRef = ref<HTMLCanvasElement | null>(null)
const outputCanvasRef = ref<HTMLCanvasElement | null>(null)
const compositeCanvasRef = ref<HTMLCanvasElement | null>(null)

const isStreaming = ref(false)
const isRecording = ref(false)
const selectedScene = ref('cyberpunk')
const selectedBg = ref('gradient')
const recordingTime = ref(0)

let mediaStream: MediaStream | null = null
let animationFrame: number | null = null
let threeScene: THREE.Scene | null = null
let threeCamera: THREE.PerspectiveCamera | null = null
let threeRenderer: THREE.WebGLRenderer | null = null
let controls: OrbitControls | null = null
let recordedChunks: Blob[] = []
let mediaRecorder: MediaRecorder | null = null

// 场景配置
const scenes = [
  { id: 'cyberpunk', name: '赛博修仙', desc: '霓虹灯+古风元素' },
  { id: 'stage', name: '电音舞台', desc: '炫酷灯光' },
  { id: 'studio', name: '演播厅', desc: '商务风格' },
]

// 背景配置
const backgrounds = [
  { id: 'gradient', name: '渐变背景' },
  { id: 'neon', name: '霓虹背景' },
  { id: 'mountains', name: '仙山背景' },
]

// 初始化摄像头
async function initCamera() {
  try {
    mediaStream = await navigator.mediaDevices.getUserMedia({
      video: { width: 1280, height: 720, facingMode: 'user' },
      audio: false
    })
    if (videoRef.value) {
      videoRef.value.srcObject = mediaStream
      await videoRef.value.play()
      isStreaming.value = true
      startProcessing()
    }
  } catch (err) {
    console.error('摄像头访问失败:', err)
    alert('无法访问摄像头，请确保已授予权限')
  }
}

// 停止摄像头
function stopCamera() {
  if (mediaStream) {
    mediaStream.getTracks().forEach(track => track.stop())
    mediaStream = null
  }
  if (animationFrame) {
    cancelAnimationFrame(animationFrame)
    animationFrame = null
  }
  isStreaming.value = false
}

// 简单的绿幕抠像（基于颜色）
function simpleChromaKey(ctx: CanvasRenderingContext2D, _video: HTMLVideoElement, width: number, height: number) {
  const imageData = ctx.getImageData(0, 0, width, height)
  const data = imageData.data
  
  // 绿色幕布颜色范围
  const greenMin = { r: 0, g: 100, b: 0 }
  const greenMax = { r: 100, g: 255, b: 100 }
  
  for (let i = 0; i < data.length; i += 4) {
    const r = data[i]
    const g = data[i + 1]
    const b = data[i + 2]
    
    // 检测绿色并使其透明
    if (r >= greenMin.r && r <= greenMax.r &&
        g >= greenMin.g && g <= greenMax.g &&
        b >= greenMin.b && b <= greenMax.b) {
      // 添加一些容差
      if (g > r + 20 && g > b + 20) {
        data[i + 3] = 0 // 透明
      }
    }
  }
  
  ctx.putImageData(imageData, 0, 0)
}

// 启动处理循环
function startProcessing() {
  if (!videoRef.value || !canvasRef.value || !outputCanvasRef.value) return
  
  const video = videoRef.value
  const canvas = canvasRef.value
  const outputCanvas = outputCanvasRef.value
  const ctx = canvas.getContext('2d', { willReadFrequently: true })!
  const outCtx = outputCanvas.getContext('2d')!
  
  canvas.width = video.videoWidth || 1280
  canvas.height = video.videoHeight || 720
  outputCanvas.width = canvas.width
  outputCanvas.height = canvas.height
  
  function process() {
    if (!isStreaming.value) return
    
    // 绘制视频帧
    ctx.drawImage(video, 0, 0, canvas.width, canvas.height)
    
    // 简单的绿幕抠像
    simpleChromaKey(ctx, video, canvas.width, canvas.height)
    
    // 绘制到输出画布
    outCtx.drawImage(canvas, 0, 0)
    
    // 更新3D场景
    updateThreeScene()
    
    // 合成最终画面
    compositeFinal()
    
    animationFrame = requestAnimationFrame(process)
  }
  
  process()
}

// 合成最终画面
function compositeFinal() {
  if (!outputCanvasRef.value || !compositeCanvasRef.value) return
  
  const compCanvas = compositeCanvasRef.value
  const compCtx = compCanvas.getContext('2d')!
  const outCanvas = outputCanvasRef.value
  
  compCanvas.width = 1280
  compCanvas.height = 720
  
  // 先绘制3D背景
  if (threeCanvasRef.value) {
    compCtx.drawImage(threeCanvasRef.value, 0, 0, compCanvas.width, compCanvas.height)
  } else {
    // 备用：绘制纯色背景
    drawBackground(compCtx, compCanvas.width, compCanvas.height)
  }
  
  // 叠加抠像后的人像
  compCtx.globalAlpha = 0.9
  compCtx.drawImage(outCanvas, 0, 0, compCanvas.width, compCanvas.height)
  compCtx.globalAlpha = 1.0
}

// 绘制背景
function drawBackground(ctx: CanvasRenderingContext2D, width: number, height: number) {
  if (selectedBg.value === 'gradient') {
    const gradient = ctx.createLinearGradient(0, 0, width, height)
    gradient.addColorStop(0, '#1a0a2e')
    gradient.addColorStop(0.5, '#16213e')
    gradient.addColorStop(1, '#0f3460')
    ctx.fillStyle = gradient
    ctx.fillRect(0, 0, width, height)
  } else if (selectedBg.value === 'neon') {
    ctx.fillStyle = '#0a0a0f'
    ctx.fillRect(0, 0, width, height)
    // 绘制霓虹线条
    ctx.strokeStyle = '#ff00ff'
    ctx.lineWidth = 2
    for (let i = 0; i < width; i += 50) {
      ctx.beginPath()
      ctx.moveTo(i, 0)
      ctx.lineTo(i, height)
      ctx.stroke()
    }
    ctx.strokeStyle = '#00ffff'
    for (let i = 0; i < height; i += 50) {
      ctx.beginPath()
      ctx.moveTo(0, i)
      ctx.lineTo(width, i)
      ctx.stroke()
    }
  } else if (selectedBg.value === 'mountains') {
    const gradient = ctx.createLinearGradient(0, 0, 0, height)
    gradient.addColorStop(0, '#1a1a2e')
    gradient.addColorStop(0.6, '#16213e')
    gradient.addColorStop(1, '#0f0f1a')
    ctx.fillStyle = gradient
    ctx.fillRect(0, 0, width, height)
    // 绘制山峰
    ctx.fillStyle = '#2a2a4a'
    ctx.beginPath()
    ctx.moveTo(0, height)
    ctx.lineTo(200, height - 200)
    ctx.lineTo(400, height - 100)
    ctx.lineTo(600, height - 300)
    ctx.lineTo(800, height - 150)
    ctx.lineTo(1000, height - 250)
    ctx.lineTo(1280, height - 100)
    ctx.lineTo(1280, height)
    ctx.fill()
  }
}

// 初始化 Three.js 场景
function initThreeJS() {
  if (!threeCanvasRef.value) return
  
  const canvas = threeCanvasRef.value
  canvas.width = 1280
  canvas.height = 720
  
  // 场景
  threeScene = new THREE.Scene()
  
  // 相机
  threeCamera = new THREE.PerspectiveCamera(75, canvas.width / canvas.height, 0.1, 1000)
  threeCamera.position.z = 5
  
  // 渲染器
  threeRenderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true })
  threeRenderer.setSize(canvas.width, canvas.height)
  threeRenderer.setClearColor(0x000000, 0)
  
  // 轨道控制
  controls = new OrbitControls(threeCamera, canvas)
  controls.enableDamping = true
  
  // 添加赛博修仙元素
  addCyberpunkElements()
  
  // 动画循环
  animateThree()
}

// 添加赛博修仙元素
function addCyberpunkElements() {
  if (!threeScene) return
  
  // 霓虹网格地面
  const gridHelper = new THREE.GridHelper(20, 20, 0xff00ff, 0x00ffff)
  gridHelper.position.y = -2
  threeScene.add(gridHelper)
  
  // 漂浮的光球
  const sphereGeometry = new THREE.SphereGeometry(0.3, 32, 32)
  const sphereMaterial = new THREE.MeshBasicMaterial({ color: 0xff00ff })
  
  for (let i = 0; i < 5; i++) {
    const sphere = new THREE.Mesh(sphereGeometry, sphereMaterial.clone())
    sphere.position.set(
      (Math.random() - 0.5) * 8,
      Math.random() * 3,
      (Math.random() - 0.5) * 5 - 2
    )
    sphere.userData.speed = 0.01 + Math.random() * 0.02
    sphere.userData.originalY = sphere.position.y
    sphere.material.color.setHex(Math.random() > 0.5 ? 0xff00ff : 0x00ffff)
    threeScene.add(sphere)
  }
  
  // 3D文字 "XR"
  // 这里用简单的几何体代替
  
  // 环境光
  const ambientLight = new THREE.AmbientLight(0xffffff, 0.5)
  threeScene.add(ambientLight)
  
  // 点光源
  const pointLight = new THREE.PointLight(0xff00ff, 1, 100)
  pointLight.position.set(0, 5, 5)
  threeScene.add(pointLight)
  
  const pointLight2 = new THREE.PointLight(0x00ffff, 1, 100)
  pointLight2.position.set(-5, 3, -5)
  threeScene.add(pointLight2)
}

// 更新3D场景
function updateThreeScene() {
  if (!threeScene || !threeCamera || !controls) return
  
  // 动画：浮动光球
  threeScene.children.forEach(child => {
    if (child.userData.speed) {
      child.position.y = child.userData.originalY + Math.sin(Date.now() * 0.001) * 0.5
    }
  })
  
  controls.update()
}

// Three.js 动画循环
function animateThree() {
  if (!threeRenderer || !threeScene || !threeCamera) return
  
  threeRenderer.render(threeScene, threeCamera)
  requestAnimationFrame(animateThree)
}

// 切换场景
function switchScene(sceneId: string) {
  selectedScene.value = sceneId
  // 重新初始化3D场景
  if (threeScene) {
    while (threeScene.children.length > 0) {
      threeScene.remove(threeScene.children[0])
    }
    addCyberpunkElements()
  }
}

// 切换背景
function switchBackground(bgId: string) {
  selectedBg.value = bgId
}

// 开始录制
function startRecording() {
  if (!compositeCanvasRef.value) return
  
  recordedChunks = []
  const canvas = compositeCanvasRef.value
  const stream = canvas.captureStream(30)
  
  mediaRecorder = new MediaRecorder(stream, {
    mimeType: 'video/webm;codecs=vp9'
  })
  
  mediaRecorder.ondataavailable = (event) => {
    if (event.data.size > 0) {
      recordedChunks.push(event.data)
    }
  }
  
  mediaRecorder.onstop = () => {
    const blob = new Blob(recordedChunks, { type: 'video/webm' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `XRShowMaster_${new Date().toISOString().slice(0,19).replace(/:/g,'-')}.webm`
    a.click()
    URL.revokeObjectURL(url)
  }
  
  mediaRecorder.start()
  isRecording.value = true
  recordingTime.value = 0
  
  // 计时
  const timer = setInterval(() => {
    if (isRecording.value) {
      recordingTime.value++
    } else {
      clearInterval(timer)
    }
  }, 1000)
}

// 停止录制
function stopRecording() {
  if (mediaRecorder && isRecording.value) {
    mediaRecorder.stop()
    isRecording.value = false
  }
}

// 格式化时间
function formatTime(seconds: number) {
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`
}

onMounted(() => {
  initThreeJS()
})

onUnmounted(() => {
  stopCamera()
  if (threeRenderer) {
    threeRenderer.dispose()
  }
})
</script>

<template>
  <div class="app">
    <!-- 顶部标题栏 -->
    <header class="header">
      <h1>🎭 XRShowMaster</h1>
      <span class="subtitle">虚拟演播室 - 赛博修仙版</span>
    </header>
    
    <div class="main-content">
      <!-- 左侧控制面板 -->
      <aside class="left-panel">
        <div class="panel-section">
          <h3>📹 摄像头</h3>
          <button v-if="!isStreaming" @click="initCamera" class="btn btn-primary">
            启动摄像头
          </button>
          <button v-else @click="stopCamera" class="btn btn-danger">
            停止摄像头
          </button>
        </div>
        
        <div class="panel-section">
          <h3>🎬 场景选择</h3>
          <div class="scene-list">
            <div 
              v-for="scene in scenes" 
              :key="scene.id"
              class="scene-item"
              :class="{ active: selectedScene === scene.id }"
              @click="switchScene(scene.id)"
            >
              <span class="scene-name">{{ scene.name }}</span>
              <span class="scene-desc">{{ scene.desc }}</span>
            </div>
          </div>
        </div>
        
        <div class="panel-section">
          <h3>🖼️ 背景选择</h3>
          <div class="bg-list">
            <button 
              v-for="bg in backgrounds" 
              :key="bg.id"
              class="btn"
              :class="{ 'btn-primary': selectedBg === bg.id, 'btn-secondary': selectedBg !== bg.id }"
              @click="switchBackground(bg.id)"
            >
              {{ bg.name }}
            </button>
          </div>
        </div>
        
        <div class="panel-section">
          <h3>⏺ 录制控制</h3>
          <div class="recording-controls">
            <button v-if="!isRecording" @click="startRecording" class="btn btn-record">
              开始录制
            </button>
            <button v-else @click="stopRecording" class="btn btn-stop">
              停止录制
            </button>
            <span v-if="isRecording" class="recording-time">
              🔴 {{ formatTime(recordingTime) }}
            </span>
          </div>
        </div>
      </aside>
      
      <!-- 中间预览区 -->
      <main class="preview-area">
        <!-- 隐藏的视频元素 -->
        <video ref="videoRef" style="display: none" muted></video>
        <canvas ref="canvasRef" style="display: none"></canvas>
        <canvas ref="outputCanvasRef" style="display: none"></canvas>
        
        <!-- 3D场景画布 -->
        <canvas ref="threeCanvasRef" class="three-canvas"></canvas>
        
        <!-- 最终合成画布 -->
        <canvas ref="compositeCanvasRef" class="composite-canvas"></canvas>
        
        <div v-if="!isStreaming" class="placeholder">
          <p>点击"启动摄像头"开始</p>
        </div>
      </main>
      
      <!-- 右侧信息栏 -->
      <aside class="right-panel">
        <div class="panel-section">
          <h3>ℹ️ 当前状态</h3>
          <div class="status-info">
            <p>场景: {{ scenes.find(s => s.id === selectedScene)?.name }}</p>
            <p>背景: {{ backgrounds.find(b => b.id === selectedBg)?.name }}</p>
            <p>分辨率: 1280 x 720</p>
            <p>帧率: 30 FPS</p>
          </div>
        </div>
        
        <div class="panel-section">
          <h3>💡 使用提示</h3>
          <ul class="tips">
            <li>使用绿色背景效果最佳</li>
            <li>调整光线可提升抠像质量</li>
            <li>录制完成后自动下载</li>
          </ul>
        </div>
      </aside>
    </div>
  </div>
</template>

<style scoped>
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

.app {
  width: 100vw;
  height: 100vh;
  background: #0a0a0f;
  color: #fff;
  display: flex;
  flex-direction: column;
  font-family: 'Microsoft YaHei', sans-serif;
}

.header {
  background: linear-gradient(90deg, #1a0a2e 0%, #16213e 100%);
  padding: 12px 24px;
  display: flex;
  align-items: center;
  gap: 16px;
  border-bottom: 2px solid #ff00ff;
}

.header h1 {
  font-size: 24px;
  background: linear-gradient(90deg, #ff00ff, #00ffff);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
}

.subtitle {
  color: #888;
  font-size: 14px;
}

.main-content {
  flex: 1;
  display: flex;
  overflow: hidden;
}

.left-panel, .right-panel {
  width: 240px;
  background: #12121a;
  padding: 16px;
  overflow-y: auto;
  border-right: 1px solid #333;
}

.right-panel {
  border-right: none;
  border-left: 1px solid #333;
}

.panel-section {
  margin-bottom: 24px;
}

.panel-section h3 {
  font-size: 14px;
  color: #00ffff;
  margin-bottom: 12px;
  padding-bottom: 8px;
  border-bottom: 1px solid #333;
}

.btn {
  width: 100%;
  padding: 10px 16px;
  border: none;
  border-radius: 6px;
  cursor: pointer;
  font-size: 14px;
  transition: all 0.2s;
  margin-bottom: 8px;
}

.btn-primary {
  background: linear-gradient(90deg, #ff00ff, #00ffff);
  color: #000;
  font-weight: bold;
}

.btn-secondary {
  background: #333;
  color: #fff;
}

.btn-danger {
  background: #ff4444;
  color: #fff;
}

.btn-record {
  background: #ff0000;
  color: #fff;
  font-weight: bold;
}

.btn-stop {
  background: #666;
  color: #fff;
}

.btn:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(255, 0, 255, 0.3);
}

.scene-list, .bg-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.scene-item {
  padding: 12px;
  background: #1a1a2e;
  border-radius: 6px;
  cursor: pointer;
  border: 2px solid transparent;
  transition: all 0.2s;
}

.scene-item:hover {
  background: #2a2a4e;
}

.scene-item.active {
  border-color: #ff00ff;
  background: #2a2a4e;
}

.scene-name {
  display: block;
  font-weight: bold;
  color: #fff;
}

.scene-desc {
  font-size: 12px;
  color: #888;
}

.preview-area {
  flex: 1;
  position: relative;
  background: #000;
  display: flex;
  align-items: center;
  justify-content: center;
}

.three-canvas {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
}

.composite-canvas {
  position: absolute;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  object-fit: contain;
}

.placeholder {
  position: absolute;
  color: #666;
  font-size: 18px;
}

.recording-controls {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.recording-time {
  color: #ff0000;
  font-size: 18px;
  text-align: center;
  animation: pulse 1s infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.status-info p {
  margin-bottom: 8px;
  font-size: 13px;
  color: #ccc;
}

.tips {
  list-style: none;
  font-size: 12px;
  color: #888;
}

.tips li {
  margin-bottom: 8px;
  padding-left: 12px;
  position: relative;
}

.tips li::before {
  content: '•';
  position: absolute;
  left: 0;
  color: #ff00ff;
}
</style>
