"""DEMOSTRACIÓN DE SOFTWARE. Datos sintéticos; prohibido reportar métricas como físicas."""
import csv, json, pathlib, numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from sklearn.preprocessing import StandardScaler
from sklearn.neural_network import MLPClassifier
from sklearn.metrics import accuracy_score, precision_recall_fscore_support, confusion_matrix
from sklearn.model_selection import train_test_split

BASE=pathlib.Path(__file__).resolve().parent
RNG=np.random.default_rng(20261111)
CLASSES=np.array(['CERCA','INTERMEDIO','LEJOS'])
# Generación artificial de lecturas con superposición intencionada entre clases.
mu={'CERCA':-49,'INTERMEDIO':-66,'LEJOS':-79}
rows=[]
for clase in CLASSES:
 for sesion in range(20):
  sesion_id=f'{clase[:2]}-{sesion:02}'
  shift=float(RNG.normal(0,4.4))
  for muestra in range(12):
   rssi=RNG.normal(mu[clase]+shift,5.8,size=12)
   count=int(np.clip(RNG.normal({'CERCA':11,'INTERMEDIO':9,'LEJOS':7}[clase],1.8),2,12))
   rows.append([sesion_id,muestra,clase,round(float(rssi.mean()),3),round(float(rssi.std(ddof=1)),3),int(rssi.min()),int(rssi.max()),count])
with (BASE/'datos_SIMULADOS_no_fisicos.csv').open('w',newline='',encoding='utf-8') as f:
 w=csv.writer(f);w.writerow(['sesion_id','muestra','clase_real_SIMULADA','rssi_media_dbm','rssi_desv_db','rssi_min_dbm','rssi_max_dbm','paquetes_recibidos_de_12']);w.writerows(rows)
# Partición agrupada por sesiones: evita datos de una misma sesión en train y test.
tr,va,te=[],[],[]
for c in CLASSES:
 sesiones=[f'{c[:2]}-{j:02}' for j in range(20)]
 rng=np.random.default_rng(20261111+len(c))
 rng.shuffle(sesiones)
 tr+=sesiones[:14];va+=sesiones[14:17];te+=sesiones[17:]
sets={'train':set(tr),'val':set(va),'test':set(te)}
def subset(name):
 sel=[r for r in rows if r[0] in sets[name]]
 return np.array([r[3:] for r in sel],float),np.array([r[2] for r in sel]),sel
Xtr,ytr,_=subset('train');Xva,yva,_=subset('val');Xte,yte,_=subset('test')
std=StandardScaler().fit(Xtr)
model=MLPClassifier(hidden_layer_sizes=(8,),activation='relu',solver='adam',learning_rate_init=.006,random_state=21,batch_size=24,max_iter=1,warm_start=True)
losses=[];acc_train=[];acc_val=[]
for ep in range(70):
 model.partial_fit(std.transform(Xtr),ytr,classes=CLASSES)
 losses.append(float(model.loss_))
 acc_train.append(float(accuracy_score(ytr,model.predict(std.transform(Xtr)))))
 acc_val.append(float(accuracy_score(yva,model.predict(std.transform(Xva)))))
pred=model.predict(std.transform(Xte))
acc=float(accuracy_score(yte,pred))
p,r,f1,sup=precision_recall_fscore_support(yte,pred,labels=CLASSES,zero_division=0)
mat=confusion_matrix(yte,pred,labels=CLASSES)
metrics={'contexto':'SOLO DEMOSTRACIÓN SOFTWARE CON DATOS SINTÉTICOS; NO RESULTADOS DE UBICAJA FÍSICO',
         'data':{'N':len(rows),'train':len(ytr),'validacion':len(yva),'test':len(yte)},
         'accuracy_test_sintetico':acc,
         'por_clase':[{"clase":str(c),"precision":float(pi),"recall":float(ri),"f1":float(fi),"n_test":int(si)} for c,pi,ri,fi,si in zip(CLASSES,p,r,f1,sup)],
         'matriz_confusion':mat.tolist()}
(BASE/'resultados_SOLO_SIMULACION.json').write_text(json.dumps(metrics,indent=2,ensure_ascii=False),encoding='utf-8')
# Figuras rotuladas visiblemente para impedir que se confundan con mediciones reales.
fig,ax=plt.subplots(figsize=(8.1,4.7));ax.plot(losses,label='Pérdida (entrenamiento)');ax2=ax.twinx();ax2.plot(acc_train,label='Accuracy train',linestyle='--');ax2.plot(acc_val,label='Accuracy validación',linestyle=':');ax.set_xlabel('Época');ax.set_ylabel('Loss');ax2.set_ylabel('Accuracy');ax.set_title('MLP con RSSI SIMULADO - NO VALIDACIÓN FÍSICA');fig.text(.5,.52,'DATOS SINTÉTICOS',ha='center',va='center',fontsize=30,alpha=.16,rotation=20);ax.legend(loc='upper center');ax2.legend(loc='center right');fig.tight_layout();fig.savefig(BASE/'curvas_SOLO_SIMULACION.png',dpi=300);plt.close(fig)
fig,ax=plt.subplots(figsize=(8,4.8));idx=np.arange(3);width=.22
for offset,label,vals in [(-width,'Precisión',p),(0,'Recall',r),(width,'F1',f1)]:ax.bar(idx+offset,vals,width,label=label)
ax.set_xticks(idx);ax.set_xticklabels(CLASSES);ax.set_ylim(0,1.05);ax.set_ylabel('Proporción');ax.set_title('Métricas por clase - DATA SINTÉTICA');ax.legend();fig.text(.5,.5,'SIMULADO',ha='center',va='center',fontsize=34,alpha=.16,rotation=20);fig.tight_layout();fig.savefig(BASE/'barras_SOLO_SIMULACION.png',dpi=300);plt.close(fig)
fig,ax=plt.subplots(figsize=(5.5,5));ax.imshow(mat,cmap='Blues');ax.set_xticks(range(3),CLASSES,rotation=15);ax.set_yticks(range(3),CLASSES);ax.set_xlabel('Predicción');ax.set_ylabel('Clase sintética');
for i in range(3):
 for j in range(3): ax.text(j,i,str(mat[i,j]),ha='center',va='center')
ax.set_title('Matriz confusión - SIMULADA');fig.tight_layout();fig.savefig(BASE/'confusion_SOLO_SIMULACION.png',dpi=300);plt.close(fig)
print('DEMOSTRACIÓN CON DATOS SINTÉTICOS:',len(rows),'muestras; accuracy',round(acc,3),'NO REPORTAR COMO PROTOTIPO')
