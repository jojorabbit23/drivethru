import json,struct,sys
for p in sys.argv[1:]:
    d=open(p,'rb').read(); n=struct.unpack('<I',d[12:16])[0]; j=json.loads(d[20:20+n])
    print('=====',p); print('asset',j.get('asset'))
    acc=j['accessors']
    tot=0
    for m in j['meshes']:
        t=0
        for pr in m['primitives']:
            if 'indices' in pr: t+=acc[pr['indices']]['count']//3
            else: t+=acc[pr['attributes']['POSITION']]['count']//3
        tot+=t
        print(' mesh %-40s tris %6d prims %d mat %s'%(m.get('name'),t,len(m['primitives']),[pr.get('material') for pr in m['primitives']]))
    print(' total tris',tot)
    print(' materials',[ (i,m.get('name')) for i,m in enumerate(j.get('materials',[]))])
    print(' images',[(i.get('name'),i.get('mimeType')) for i in j.get('images',[])])
    print(' skins',[(s.get('name'),len(s['joints'])) for s in j.get('skins',[])])
    print(' anims',[(a.get('name'),len(a['channels'])) for a in j.get('animations',[])])
    print(' nodes with mesh',[(nd.get('name'),nd.get('mesh'),nd.get('skin')) for nd in j['nodes'] if 'mesh' in nd])
    print(' ext',j.get('extensionsUsed'))
