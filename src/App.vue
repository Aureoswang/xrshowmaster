<script setup lang="ts">
import { ref, onMounted, onUnmounted } from 'vue'
import * as THREE from 'three'
import { OrbitControls } from 'three/examples/jsm/controls/OrbitControls.js'
import { FontLoader } from 'three/examples/jsm/loaders/FontLoader.js'
import { TextGeometry } from 'three/examples/jsm/geometries/TextGeometry.js'

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

// 多机位相关状态
const cameras = ref<MediaDeviceInfo[]>([])
const selectedCameraId = ref('')
const activeCameraIndex = ref(0) // 当前使用的主机位
const showMultiPreview = ref(false) // 是否显示多机位预览

// 预置的虚拟机位（模拟多机位效果）
const virtualCameras = ref([
  { id: 'cam1', name: '机位 1 - 主镜头', active: true, position: { x: 0, y: 0, z: 5 }, fov: 75 },
  { id: 'cam2', name: '机位 2 - 侧全景', active: false, position: { x: -3, y: 1, z: 4 }, fov: 90 },
  { id: 'cam3', name: '机位 3 - 特写', active: false, position: { x: 0, y: 0, z: 2 }, fov: 50 },
])

// 相机位置控制状态
const cameraDistance = ref(5) // 距离
const cameraAngle = ref(0) // 水平角度
const cameraHeight = ref(0) // 高度
const keyPressed = ref<Set<string>>(new Set()) // 按键状态

// 3D文本相关状态
const showText3D = ref(false)
const text3DContent = ref('XRShowMaster')
const text3DSize = ref(0.5)
const text3DX = ref(0)
const text3DY = ref(1)
const text3DZ = ref(0)
const text3DScale = ref(1)
const text3DFont = ref('helvetiker')
const text3DBold = ref(false)
const text3DColor = ref('#ff00ff')
let text3DMesh: THREE.Mesh | null = null

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

// 获取可用摄像头列表
async function getCameraList() {
  try {
    // 先请求权限获取设备列表
    await navigator.mediaDevices.getUserMedia({ video: true })
    const devices = await navigator.mediaDevices.enumerateDevices()
    cameras.value = devices.filter(device => device.kind === 'videoinput')
    if (cameras.value.length > 0 && !selectedCameraId.value) {
      selectedCameraId.value = cameras.value[0].deviceId
    }
    console.log('可用摄像头:', cameras.value)
  } catch (err) {
    console.error('获取摄像头列表失败:', err)
  }
}

// 切换摄像头
async function switchCamera(deviceId: string) {
  selectedCameraId.value = deviceId
  // 重新初始化摄像头
  if (isStreaming.value) {
    stopCamera()
    await initCamera()
  }
}

// 切换机位（模拟多机位切换）
function switchCameraPosition(index: number) {
  if (index < 0 || index >= virtualCameras.value.length) return
  
  // 更新激活状态
  virtualCameras.value.forEach((cam, i) => {
    cam.active = (i === index)
  })
  activeCameraIndex.value = index
  
  // 可以在这里添加镜头切换特效
  console.log('切换到机位:', index + 1)
}

// 切换到下一个机位
function nextCamera() {
  const nextIndex = (activeCameraIndex.value + 1) % virtualCameras.value.length
  switchCameraPosition(nextIndex)
}

// 切换到上一个机位
function prevCamera() {
  const prevIndex = (activeCameraIndex.value - 1 + virtualCameras.value.length) % virtualCameras.value.length
  switchCameraPosition(prevIndex)
}

// 初始化摄像头
async function initCamera() {
  try {
    const videoConstraints: MediaTrackConstraints = {
      width: 1280,
      height: 720,
      facingMode: 'user'
    }
    
    // 如果选择了特定摄像头，使用设备ID
    if (selectedCameraId.value) {
      delete videoConstraints.facingMode
      videoConstraints.deviceId = { exact: selectedCameraId.value }
    }
    
    mediaStream = await navigator.mediaDevices.getUserMedia({
      video: videoConstraints,
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

// 加载字体并创建3D文本

function createText3D() {
  if (!threeScene) return
  
  // 移除旧的3D文本
  if (text3DMesh) {
    threeScene.remove(text3DMesh)
    text3DMesh.geometry.dispose()
    ;(text3DMesh.material as THREE.Material).dispose()
    text3DMesh = null
  }
  
  if (!showText3D.value || !text3DContent.value) return
  
  const loader = new FontLoader()
  
  // 字体URL - 使用Three.js内置字体
  const fontUrl = `https://threejs.org/examples/fonts/${text3DFont.value}_${text3DBold.value ? 'bold' : 'regular'}.typeface.json`
  
  loader.load(fontUrl, (font) => {
    const geometry = new TextGeometry(text3DContent.value, {
      font: font,
      size: text3DSize.value,
      depth: 0.1, // 厚度
      curveSegments: 12,
      bevelEnabled: true,
      bevelThickness: 0.02,
      bevelSize: 0.01,
      bevelOffset: 0,
      bevelSegments: 5
    })
    
    // 居中
    geometry.computeBoundingBox()
    const centerOffset = -0.5 * (geometry.boundingBox!.max.x - geometry.boundingBox!.min.x)
    geometry.translate(centerOffset, 0, 0)
    
    const material = new THREE.MeshPhongMaterial({ 
      color: text3DColor.value,
      specular: 0xffffff,
      shininess: 30
    })
    
    text3DMesh = new THREE.Mesh(geometry, material)
    text3DMesh.position.set(text3DX.value, text3DY.value, text3DZ.value)
    text3DMesh.scale.setScalar(text3DScale.value)
    
    threeScene!.add(text3DMesh)
  })
}

// 更新3D文本
function updateText3D() {
  if (!threeScene) return
  
  // 移除旧的
  if (text3DMesh) {
    threeScene.remove(text3DMesh)
    text3DMesh.geometry.dispose()
    ;(text3DMesh.material as THREE.Material).dispose()
    text3DMesh = null
  }
  
  // 重新创建
  if (showText3D.value && text3DContent.value) {
    createText3D()
  }
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
  getCameraList()
  
  // 键盘事件监听
  window.addEventListener('keydown', handleKeyDown)
  window.addEventListener('keyup', handleKeyUp)
  // 启动键盘控制循环
  startKeyboardControlLoop()
})

onUnmounted(() => {
  stopCamera()
  if (threeRenderer) {
    threeRenderer.dispose()
  }
  // 移除键盘事件监听
  window.removeEventListener('keydown', handleKeyDown)
  window.removeEventListener('keyup', handleKeyUp)
})

// 键盘按键处理
function handleKeyDown(e: KeyboardEvent) {
  const key = e.key.toLowerCase()
  keyPressed.value.add(key)
  
  // 切换机位
  if (key === '1') switchCameraPosition(0)
  if (key === '2') switchCameraPosition(1)
  if (key === '3') switchCameraPosition(2)
}

function handleKeyUp(e: KeyboardEvent) {
  const key = e.key.toLowerCase()
  keyPressed.value.delete(key)
}

// 键盘控制循环
const keyboardLoopId = ref<number | null>(null)

function startKeyboardControlLoop() {
  function loop() {
    if (!threeCamera) {
      keyboardLoopId.value = requestAnimationFrame(loop)
      return
    }
    
    const speed = 0.05
    const rotateSpeed = 0.03
    
    // W - 前进（推近）
    if (keyPressed.value.has('w')) {
      cameraDistance.value = Math.max(1, cameraDistance.value - speed * 10)
    }
    // S - 后退（拉远）
    if (keyPressed.value.has('s')) {
      cameraDistance.value = Math.min(15, cameraDistance.value + speed * 10)
    }
    // Q - 左转
    if (keyPressed.value.has('q')) {
      cameraAngle.value -= rotateSpeed
    }
    // E - 右转（增加E键）
    if (keyPressed.value.has('e')) {
      cameraAngle.value += rotateSpeed
    }
    // A - 左移
    if (keyPressed.value.has('a')) {
      if (threeCamera) {
        threeCamera.position.x -= speed
      }
    }
    // D - 右移
    if (keyPressed.value.has('d')) {
      if (threeCamera) {
        threeCamera.position.x += speed
      }
    }
    // R - 上升
    if (keyPressed.value.has('r')) {
      cameraHeight.value += speed
    }
    // F - 下降
    if (keyPressed.value.has('f')) {
      cameraHeight.value -= speed
    }
    
    // 更新相机位置（基于极坐标）
    if (threeCamera) {
      const x = Math.sin(cameraAngle.value) * cameraDistance.value
      const z = Math.cos(cameraAngle.value) * cameraDistance.value
      threeCamera.position.x = x
      threeCamera.position.z = z
      threeCamera.position.y = cameraHeight.value
      threeCamera.lookAt(0, 0, 0)
    }
    
    keyboardLoopId.value = requestAnimationFrame(loop)
  }
  loop()
}
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
        
        <!-- 多机位控制 -->
        <div class="panel-section">
          <h3>🎥 多机位</h3>
          <div class="camera-select" v-if="cameras.length > 1">
            <label>选择摄像头:</label>
            <select v-model="selectedCameraId" @change="switchCamera(selectedCameraId)" class="select-input">
              <option v-for="cam in cameras" :key="cam.deviceId" :value="cam.deviceId">
                {{ cam.label || `摄像头 ${cameras.indexOf(cam) + 1}` }}
              </option>
            </select>
          </div>
          
          <div class="camera-position-list">
            <div 
              v-for="(cam, index) in virtualCameras" 
              :key="cam.id"
              class="camera-position-item"
              :class="{ active: activeCameraIndex === index }"
              @click="switchCameraPosition(index)"
            >
              <span class="cam-indicator" :class="{ active: cam.active }">●</span>
              <span class="cam-name">{{ cam.name }}</span>
            </div>
          </div>
          
          <div class="camera-switch-btns">
            <button @click="prevCamera" class="btn btn-small" title="上一个机位">◀</button>
            <span class="camera-position-info">{{ activeCameraIndex + 1 }} / {{ virtualCameras.length }}</span>
            <button @click="nextCamera" class="btn btn-small" title="下一个机位">▶</button>
          </div>
          
          <button @click="showMultiPreview = !showMultiPreview" class="btn btn-secondary btn-small" style="margin-top: 8px;">
            {{ showMultiPreview ? '隐藏预览' : '多机位预览' }}
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
        
        <!-- 3D文本控制 -->
        <div class="panel-section">
          <h3>🔤 3D文本</h3>
          <div class="text3d-controls">
            <label class="checkbox-label">
              <input type="checkbox" v-model="showText3D" @change="updateText3D">
              显示3D文本
            </label>
            
            <div class="control-group" v-if="showText3D">
              <label>文本内容:</label>
              <input type="text" v-model="text3DContent" @input="updateText3D" class="text-input" placeholder="输入文字...">
              
              <label>大小: {{ text3DSize }}</label>
              <input type="range" v-model.number="text3DSize" min="0.1" max="2" step="0.1" @input="updateText3D">
              
              <label>X位置: {{ text3DX }}</label>
              <input type="range" v-model.number="text3DX" min="-5" max="5" step="0.1" @input="updateText3D">
              
              <label>Y位置: {{ text3DY }}</label>
              <input type="range" v-model.number="text3DY" min="-2" max="4" step="0.1" @input="updateText3D">
              
              <label>Z位置: {{ text3DZ }}</label>
              <input type="range" v-model.number="text3DZ" min="-5" max="5" step="0.1" @input="updateText3D">
              
              <label>缩放: {{ text3DScale }}</label>
              <input type="range" v-model.number="text3DScale" min="0.5" max="3" step="0.1" @input="updateText3D">
              
              <label>字体:</label>
              <select v-model="text3DFont" @change="updateText3D" class="select-input">
                <option value="helvetiker">Helvetiker</option>
                <option value="gentilis">Gentilis</option>
                <option value="optimer">Optimer</option>
                <option value="droid/droid_sans">Droid Sans</option>
                <option value="droid/droid_sans_mono">Droid Sans Mono</option>
              </select>
              
              <label class="checkbox-label">
                <input type="checkbox" v-model="text3DBold" @change="updateText3D">
                粗体
              </label>
              
              <label>颜色:</label>
              <input type="color" v-model="text3DColor" @input="updateText3D" class="color-input">
            </div>
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
        
        <!-- 多机位预览覆盖层 -->
        <div v-if="showMultiPreview && isStreaming" class="multi-camera-overlay">
          <div class="multi-cam-grid">
            <div 
              v-for="(cam, index) in virtualCameras" 
              :key="cam.id"
              class="multi-cam-preview"
              :class="{ active: activeCameraIndex === index }"
              @click="switchCameraPosition(index)"
            >
              <div class="cam-preview-content">
                <span class="cam-preview-label">{{ cam.name }}</span>
                <span class="cam-preview-indicator" :class="{ active: cam.active }">●</span>
              </div>
            </div>
          </div>
        </div>
        
        <!-- 机位切换动画提示 -->
        <div v-if="isStreaming" class="camera-switch-indicator">
          切换到: {{ virtualCameras[activeCameraIndex]?.name }}
        </div>
        
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
            <p>机位: {{ virtualCameras[activeCameraIndex]?.name }}</p>
            <p>分辨率: 1280 x 720</p>
            <p>帧率: 30 FPS</p>
            <p>可用摄像头: {{ cameras.length }}</p>
          </div>
        </div>
        
        <div class="panel-section">
          <h3>⌨️ 键盘控制</h3>
          <ul class="tips">
            <li><kbd>W</kbd> 前进 / <kbd>S</kbd> 后退</li>
            <li><kbd>Q</kbd> 左转 / <kbd>E</kbd> 右转</li>
            <li><kbd>A</kbd> 左移 / <kbd>D</kbd> 右移</li>
            <li><kbd>R</kbd> 上升 / <kbd>F</kbd> 下降</li>
            <li><kbd>1</kbd><kbd>2</kbd><kbd>3</kbd> 切换机位</li>
          </ul>
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

/* 多机位相关样式 */
.camera-select {
  margin-bottom: 12px;
}

.camera-select label {
  display: block;
  font-size: 12px;
  color: #888;
  margin-bottom: 4px;
}

.select-input {
  width: 100%;
  padding: 8px;
  background: #1a1a2e;
  border: 1px solid #333;
  border-radius: 4px;
  color: #fff;
  font-size: 12px;
}

.camera-position-list {
  display: flex;
  flex-direction: column;
  gap: 6px;
  margin-bottom: 12px;
}

.camera-position-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: #1a1a2e;
  border-radius: 4px;
  cursor: pointer;
  border: 1px solid transparent;
  transition: all 0.2s;
}

.camera-position-item:hover {
  background: #2a2a4e;
}

.camera-position-item.active {
  border-color: #00ffff;
  background: #2a2a4e;
}

.cam-indicator {
  font-size: 10px;
  color: #666;
}

.cam-indicator.active {
  color: #00ff00;
}

.cam-name {
  font-size: 12px;
  color: #ccc;
}

.camera-switch-btns {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 12px;
}

.camera-position-info {
  font-size: 14px;
  color: #00ffff;
  font-weight: bold;
}

.btn-small {
  padding: 6px 12px;
  font-size: 12px;
  width: auto;
}

/* 多机位预览覆盖层 */
.multi-camera-overlay {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background: rgba(0, 0, 0, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 100;
}

.multi-cam-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
  padding: 16px;
  max-width: 600px;
}

.multi-cam-preview {
  aspect-ratio: 16/9;
  background: #1a1a2e;
  border: 2px solid #333;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.multi-cam-preview:hover {
  border-color: #ff00ff;
}

.multi-cam-preview.active {
  border-color: #00ffff;
  box-shadow: 0 0 20px rgba(0, 255, 255, 0.5);
}

.cam-preview-content {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
}

.cam-preview-label {
  font-size: 12px;
  color: #ccc;
}

.cam-preview-indicator {
  font-size: 16px;
  color: #666;
}

.cam-preview-indicator.active {
  color: #00ff00;
}

/* 机位切换提示 */
.camera-switch-indicator {
  position: absolute;
  bottom: 20px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(0, 0, 0, 0.7);
  color: #00ffff;
  padding: 8px 16px;
  border-radius: 20px;
  font-size: 14px;
  z-index: 50;
  animation: fadeInOut 2s ease-in-out;
}

@keyframes fadeInOut {
  0% { opacity: 0; }
  20% { opacity: 1; }
  80% { opacity: 1; }
  100% { opacity: 0; }
}

/* 键盘按键样式 */
kbd {
  display: inline-block;
  padding: 2px 6px;
  background: #2a2a4e;
  border: 1px solid #444;
  border-radius: 4px;
  font-family: monospace;
  font-size: 11px;
  color: #00ffff;
}

/* 3D文本控件样式 */
.text3d-controls {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.text3d-controls .control-group {
  display: flex;
  flex-direction: column;
  gap: 6px;
  padding: 8px;
  background: #1a1a2e;
  border-radius: 6px;
}

.text3d-controls label {
  font-size: 11px;
  color: #888;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 6px;
  cursor: pointer;
  color: #ccc !important;
  font-size: 12px !important;
}

.checkbox-label input {
  width: 14px;
  height: 14px;
  cursor: pointer;
}

.text-input {
  width: 100%;
  padding: 6px 8px;
  background: #0a0a0f;
  border: 1px solid #333;
  border-radius: 4px;
  color: #fff;
  font-size: 12px;
}

.text-input:focus {
  outline: none;
  border-color: #ff00ff;
}

.text3d-controls input[type="range"] {
  width: 100%;
  height: 4px;
  background: #333;
  border-radius: 2px;
  appearance: none;
  cursor: pointer;
}

.text3d-controls input[type="range"]::-webkit-slider-thumb {
  appearance: none;
  width: 12px;
  height: 12px;
  background: #ff00ff;
  border-radius: 50%;
  cursor: pointer;
}

.color-input {
  width: 100%;
  height: 30px;
  padding: 2px;
  background: #0a0a0f;
  border: 1px solid #333;
  border-radius: 4px;
  cursor: pointer;
}
</style>
