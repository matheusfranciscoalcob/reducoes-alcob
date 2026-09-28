(function(){'use strict';
const APPROVER_EMAIL='matheusferfran2010@gmail.com';
const AUTH_STORAGE_KEY='reducoes-alcob-auth-v1';
const PHOTO_BUCKET='solution-sample-photos';
const DB_NAME='controle-solucoes-midia-v1';
const monitored={
  'emulsao-history-v1':{kind:'measurements',system:'oil'},
  'decap-history-v1':{kind:'measurements',system:'pickling'},
  'emulsao-calibrations-v1':{kind:'calibrations',system:'oil'},
  'decap-calibrations-v1':{kind:'calibrations',system:'pickling'},
  'emulsao-config-v1':{kind:'settings',system:'oil'},
  'decap-config-v1':{kind:'settings',system:'pickling'},
  'emulsao-adaptive-enabled':{kind:'settings',system:'oil'},
  'decap-adaptive-enabled':{kind:'settings',system:'pickling'}
};
const baselines={oil:{measurements:new Map(),calibrations:new Map()},pickling:{measurements:new Map(),calibrations:new Map()}};
const timers=new Map();
const nativeSetItem=Storage.prototype.setItem;
let client=null,user=null,syncChain=Promise.resolve(),scriptsLoaded=false,openingPromise=null;
const gate=document.getElementById('cloudGate');

function esc(value){return String(value??'').replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]))}
function writeLocal(key,value){nativeSetItem.call(localStorage,key,value)}
function setStatus(text,state='ok'){
  const label=document.getElementById('cloudState'),pill=label?.closest('.local');
  if(label)label.textContent=text;
  if(pill)pill.className='local '+(state==='ok'?'':state);
}
function showLogin(message='',error=false){
  document.body.classList.add('cloud-locked');
  gate.innerHTML=`<div class="cloud-card"><div class="cloud-brand"><div class="mark">◒</div><div><p class="eyebrow">REDUÇÕES ALCOB</p><h1>Controle de soluções</h1></div></div><p>Entre com a mesma conta aprovada usada no sistema de reduções.</p><label>E-mail<input id="cloudEmail" type="email" autocomplete="username"></label><label>Senha<input id="cloudPassword" type="password" autocomplete="current-password"></label><div class="cloud-buttons"><button id="cloudLogin" class="cloud-primary" type="button">Entrar</button><button id="cloudSignup" class="cloud-secondary" type="button">Criar conta</button></div><p id="cloudMessage" class="cloud-message${error?' error':''}">${esc(message)}</p></div>`;
  document.getElementById('cloudLogin').onclick=signIn;
  document.getElementById('cloudSignup').onclick=signUp;
  document.getElementById('cloudPassword').onkeydown=e=>{if(e.key==='Enter')signIn()};
}
function showPending(){
  document.body.classList.add('cloud-locked');
  gate.innerHTML=`<div class="cloud-card"><div class="cloud-brand"><div class="mark">◒</div><div><p class="eyebrow">ACESSO CONTROLADO</p><h1>Aguardando aprovação</h1></div></div><p>A conta <b>${esc(user?.email)}</b> já foi registrada, mas ainda precisa ser aprovada pelo responsável do projeto Reduções ALCOB.</p><div class="cloud-buttons"><button id="cloudRefresh" class="cloud-primary" type="button">Atualizar status</button><button id="cloudPendingLogout" class="cloud-secondary" type="button">Sair</button></div><p id="cloudMessage" class="cloud-message"></p></div>`;
  document.getElementById('cloudRefresh').onclick=()=>applySession(true);
  document.getElementById('cloudPendingLogout').onclick=signOut;
}
function message(text,error=false){const el=document.getElementById('cloudMessage');if(el){el.textContent=text;el.classList.toggle('error',error)}}
async function signIn(){
  const email=document.getElementById('cloudEmail').value.trim(),password=document.getElementById('cloudPassword').value;
  if(!email||!password){message('Informe e-mail e senha.',true);return}
  message('Entrando...');
  const {error}=await client.auth.signInWithPassword({email,password});
  if(error)message(error.message,true);
}
async function signUp(){
  const email=document.getElementById('cloudEmail').value.trim(),password=document.getElementById('cloudPassword').value;
  if(!email||password.length<8){message('Informe um e-mail válido e uma senha com pelo menos 8 caracteres.',true);return}
  message('Criando a solicitação...');
  const {data,error}=await client.auth.signUp({email,password,options:{emailRedirectTo:location.href.split('#')[0]}});
  if(error){message(error.message,true);return}
  if(data.session)await applySession(true);else message('Conta criada. Confirme o e-mail recebido e aguarde a aprovação.');
}
async function signOut(){await client.auth.signOut();location.reload()}
function isApprover(){return String(user?.email||'').toLowerCase()===APPROVER_EMAIL}
async function applySession(force=false){
  const {data,error}=await client.auth.getSession();
  if(error){showLogin(error.message,true);return}
  user=data.session?.user||null;
  if(!user){showLogin();return}
  message('Verificando aprovação...');
  const access=await client.from('user_access').select('approved').eq('user_id',user.id).maybeSingle();
  if(access.error&&!isApprover()){showLogin('Não foi possível verificar a aprovação: '+access.error.message,true);return}
  if(!isApprover()&&access.data?.approved!==true){showPending();return}
  if(!scriptsLoaded){
    if(!openingPromise)openingPromise=openApplication().finally(()=>{openingPromise=null});
    await openingPromise;
  }
}

function jsonMap(rows,keyOf,valueOf){return new Map((rows||[]).map(row=>[keyOf(row),JSON.stringify(valueOf(row))]))}
async function hydrateState(){
  setStatus('Carregando histórico','syncing');
  const [measurements,calibrations,settings]=await Promise.all([
    client.from('solution_measurements').select('id,system,measured_at,payload').order('measured_at',{ascending:false}),
    client.from('solution_calibrations').select('record_id,system,payload'),
    client.from('solution_settings').select('system,config,adaptive_enabled')
  ]);
  for(const result of [measurements,calibrations,settings])if(result.error)throw result.error;
  for(const system of ['oil','pickling']){
    const history=(measurements.data||[]).filter(r=>r.system===system).map(r=>({...r.payload,id:r.id,timestamp:r.measured_at}));
    const learned=(calibrations.data||[]).filter(r=>r.system===system).map(r=>({...r.payload,recordId:r.record_id}));
    const setting=(settings.data||[]).find(r=>r.system===system);
    const prefix=system==='oil'?'emulsao':'decap';
    writeLocal(`${prefix}-history-v1`,JSON.stringify(history));
    writeLocal(`${prefix}-calibrations-v1`,JSON.stringify(learned));
    if(setting){writeLocal(`${prefix}-config-v1`,JSON.stringify(setting.config||{}));writeLocal(`${prefix}-adaptive-enabled`,String(setting.adaptive_enabled!==false))}
    baselines[system].measurements=jsonMap(history,r=>r.id,r=>r);
    baselines[system].calibrations=jsonMap(learned,r=>r.recordId,r=>r);
  }
}
function openMediaDb(){return new Promise((resolve,reject)=>{const request=indexedDB.open(DB_NAME,1);request.onupgradeneeded=()=>{const db=request.result;if(!db.objectStoreNames.contains('annotations'))db.createObjectStore('annotations',{keyPath:'key'});if(!db.objectStoreNames.contains('photos')){const store=db.createObjectStore('photos',{keyPath:'id'});store.createIndex('recordKey','recordKey',{unique:false})}};request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error)})}
async function replaceMedia(annotations,photos){
  const db=await openMediaDb();
  await new Promise((resolve,reject)=>{const tx=db.transaction(['annotations','photos'],'readwrite'),a=tx.objectStore('annotations'),p=tx.objectStore('photos');a.clear();p.clear();for(const row of annotations)a.put({key:`${row.system}:${row.measurement_id}`,system:row.system,recordId:row.measurement_id,ph:row.ph||'',alkalinity:row.alkalinity||'',dirt:row.dirt||'',updatedAt:row.updated_at});for(const row of photos)p.put(row);tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error)});
}
async function hydrateMedia(){
  const [annotations,photos]=await Promise.all([
    client.from('solution_annotations').select('measurement_id,system,ph,alkalinity,dirt,updated_at'),
    client.from('solution_photos').select('id,measurement_id,system,storage_path,original_name,added_at').order('added_at')
  ]);
  if(annotations.error)throw annotations.error;if(photos.error)throw photos.error;
  const hydrated=[];
  for(const row of photos.data||[]){
    const signed=await client.storage.from(PHOTO_BUCKET).createSignedUrl(row.storage_path,604800);
    if(!signed.error)hydrated.push({id:row.id,recordKey:`${row.system}:${row.measurement_id}`,system:row.system,recordId:row.measurement_id,name:row.original_name,dataUrl:signed.data.signedUrl,storagePath:row.storage_path,addedAt:row.added_at});
  }
  await replaceMedia(annotations.data||[],hydrated);
}
function installBridge(){
  if(Storage.prototype.setItem.__solutionCloud)return;
  function cloudSetItem(key,value){nativeSetItem.call(this,key,value);if(this===localStorage&&monitored[key])schedule(key)}
  cloudSetItem.__solutionCloud=true;Storage.prototype.setItem=cloudSetItem;
}
function schedule(key){clearTimeout(timers.get(key));timers.set(key,setTimeout(()=>{timers.delete(key);syncChain=syncChain.then(()=>syncKey(key)).catch(err=>{console.error(err);setStatus('Falha ao sincronizar','error')})},450))}
function readArray(key){try{const value=JSON.parse(localStorage.getItem(key)||'[]');return Array.isArray(value)?value:[]}catch{return[]}}
async function removeMeasurements(system,ids){
  if(!ids.length)return;
  const photos=await client.from('solution_photos').select('storage_path').eq('system',system).in('measurement_id',ids);
  if(photos.error)throw photos.error;
  const paths=(photos.data||[]).map(p=>p.storage_path);if(paths.length){const removed=await client.storage.from(PHOTO_BUCKET).remove(paths);if(removed.error)throw removed.error}
  const deleted=await client.from('solution_measurements').delete().eq('system',system).in('id',ids);if(deleted.error)throw deleted.error;
}
async function syncCollection(system,kind,key){
  const rows=readArray(key),idOf=kind==='measurements'?r=>r.id:r=>r.recordId,baseline=baselines[system][kind],current=new Map(rows.filter(r=>idOf(r)).map(r=>[idOf(r),JSON.stringify(r)]));
  const changed=rows.filter(r=>idOf(r)&&baseline.get(idOf(r))!==JSON.stringify(r));
  const removed=[...baseline.keys()].filter(id=>!current.has(id));
  if(kind==='measurements'){
    if(changed.length){const result=await client.from('solution_measurements').upsert(changed.map(r=>({id:r.id,system,measured_at:r.timestamp,payload:r})),{onConflict:'id'});if(result.error)throw result.error}
    await removeMeasurements(system,removed);
  }else{
    if(changed.length){const result=await client.from('solution_calibrations').upsert(changed.map(r=>({record_id:r.recordId,system,payload:r})),{onConflict:'record_id'});if(result.error)throw result.error}
    if(removed.length){const result=await client.from('solution_calibrations').delete().eq('system',system).in('record_id',removed);if(result.error)throw result.error}
  }
  baselines[system][kind]=current;
}
async function syncSettings(system){
  const prefix=system==='oil'?'emulsao':'decap',config=JSON.parse(localStorage.getItem(`${prefix}-config-v1`)||'{}'),adaptive=localStorage.getItem(`${prefix}-adaptive-enabled`)!=='false';
  const result=await client.from('solution_settings').upsert({system,config,adaptive_enabled:adaptive,updated_by:user.id},{onConflict:'system'});if(result.error)throw result.error;
}
async function syncKey(key){
  const spec=monitored[key];if(!spec||!user)return;
  setStatus('Sincronizando','syncing');
  if(spec.kind==='settings')await syncSettings(spec.system);else await syncCollection(spec.system,spec.kind,key);
  setStatus('Sincronizado');
}
async function saveAnnotation(data){const result=await client.from('solution_annotations').upsert({measurement_id:data.recordId,system:data.system,ph:data.ph||null,alkalinity:data.alkalinity||null,dirt:data.dirt||null,updated_by:user.id},{onConflict:'measurement_id'});if(result.error)throw result.error;setStatus('Sincronizado')}
async function savePhoto(photo){
  setStatus('Enviando fotografia','syncing');
  const blob=await (await fetch(photo.dataUrl)).blob(),path=`${photo.system}/${photo.recordId}/${photo.id}.jpg`;
  const uploaded=await client.storage.from(PHOTO_BUCKET).upload(path,blob,{contentType:'image/jpeg',upsert:false});if(uploaded.error)throw uploaded.error;
  const inserted=await client.from('solution_photos').insert({id:photo.id,measurement_id:photo.recordId,system:photo.system,storage_path:path,original_name:photo.name});
  if(inserted.error){await client.storage.from(PHOTO_BUCKET).remove([path]);throw inserted.error}
  setStatus('Sincronizado');return path;
}
async function deleteCloudPhoto(photo){
  const row=await client.from('solution_photos').select('storage_path').eq('id',photo.id).maybeSingle();if(row.error)throw row.error;
  if(row.data?.storage_path){const removed=await client.storage.from(PHOTO_BUCKET).remove([row.data.storage_path]);if(removed.error)throw removed.error}
  const deleted=await client.from('solution_photos').delete().eq('id',photo.id);if(deleted.error)throw deleted.error;setStatus('Sincronizado');
}
function loadScript(src){return new Promise((resolve,reject)=>{const script=document.createElement('script');script.src=src;script.onload=resolve;script.onerror=()=>reject(new Error('Falha ao carregar '+src));document.body.appendChild(script)})}
async function openApplication(){
  try{
    gate.innerHTML='<div class="cloud-card"><h1>Preparando o sistema</h1><p>Carregando histórico, análises e fotografias compartilhadas...</p></div>';
    await hydrateState();await hydrateMedia();installBridge();
    window.CloudSync={saveAnnotation,savePhoto,deletePhoto:deleteCloudPhoto};
    if(!scriptsLoaded){await loadScript('calculos.js?v=20260928');await loadScript('aplicacao.js?v=20260928');await loadScript('midia-relatorios.js?v=20260928');scriptsLoaded=true}
    document.body.classList.remove('cloud-locked');gate.innerHTML='';setStatus('Sincronizado');
    document.getElementById('logoutCloud').onclick=signOut;
  }catch(err){console.error(err);showLogin('Não foi possível carregar os dados compartilhados: '+(err.message||err),true)}
}
async function init(){
  const cfg=window.REDUCOES_CONFIG||{};
  if(!window.supabase||!cfg.supabaseUrl||!cfg.supabasePublishableKey){showLogin('A conexão com o Supabase não está configurada.',true);return}
  client=window.supabase.createClient(cfg.supabaseUrl,cfg.supabasePublishableKey,{auth:{storageKey:AUTH_STORAGE_KEY,persistSession:true,autoRefreshToken:true,detectSessionInUrl:true}});
  client.auth.onAuthStateChange(()=>setTimeout(()=>applySession(),0));
  await applySession();
}
init();
})();
