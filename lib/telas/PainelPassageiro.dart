import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uber/Rotas.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'dart:io';

import 'package:uber/model/Destino.dart';
import 'package:uber/model/Requisicao.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/model/util/StatusRequisicao.dart';
import 'package:uber/model/util/UsuarioFirebase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PainelPassageiro extends StatefulWidget {
  @override
  _PainelPassageiroState createState() => _PainelPassageiroState();
}

class _PainelPassageiroState extends State<PainelPassageiro> {

  TextEditingController _controllerDestino = TextEditingController(text: "av. paulista, 807");
  List<String> itensMenu = [
    "Configurações", "Deslogar"
  ];
  Completer<GoogleMapController> _controller = Completer();

  CameraPosition _posicaoCamera = CameraPosition(
      target: LatLng(-23.563999, -46.653256)
  );
  Set<Marker> _marcadores = {};

  _deslogarUsuario() async {
      FirebaseAuth auth = FirebaseAuth.instance;

      await auth.signOut();
      Navigator.pushReplacementNamed(context, Rotas.ROTA_HOME);
  }

  _escolhaMenuItem( String escolha ){

    switch(escolha){
      case "Deslogar":
        _deslogarUsuario();
      break;
      case "Configurações":

      break;
    }
  }

  _onMapCreated( GoogleMapController controller ){
    _controller.complete(controller);
  }

  _adicionarListenerLocalizacao(){
    var geolocator = Geolocator();
    var locationOptions = LocationOptions(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10
    );

    geolocator.getPositionStream(locationOptions).listen((Position position) {

      _exibirMarcadorPassageiro(position);

       _posicaoCamera = CameraPosition(
           target: LatLng(position.latitude, position.longitude),
           zoom: 19.0
       );
       _movimentarCamera(_posicaoCamera);
    });
  }

  _recuperarUltimaLocalizacaoConhecida() async {

     Position position = await Geolocator()
         .getLastKnownPosition( desiredAccuracy: LocationAccuracy.high);

     setState(() {
       if(position != null){

         _exibirMarcadorPassageiro(position);

          _posicaoCamera = CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 19.0
          );
          _movimentarCamera(_posicaoCamera);
       }
     });
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController.animateCamera(
      CameraUpdate.newCameraPosition(
        cameraPosition
      )
    );
  }

  _exibirMarcadorPassageiro(Position local) async {

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        "imagens/passageiro.png"
    ).then((BitmapDescriptor icone) {

      Marker marcadorPassageiro = Marker(
          markerId: MarkerId("marcador-passageiro"),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(
              title: "Meu local"
          ),
          icon: icone
      );

      setState(() {
        _marcadores.add(marcadorPassageiro);
      });
    });
  }

  _chamarUber() async {

    String enderecoDestino = _controllerDestino.text;

    if(enderecoDestino.isNotEmpty) {

      List<Placemark> listaEnderecos = await Geolocator()
          .placemarkFromAddress(enderecoDestino);


       if(listaEnderecos != null && listaEnderecos.length > 0){

          Placemark endereco = listaEnderecos[0];

          Destino destino = Destino();
          destino.cidade = endereco.administrativeArea;
          destino.cep = endereco.postalCode;
          destino.bairro = endereco.subLocality;
          destino.rua = endereco.thoroughfare;
          destino.numero = endereco.subThoroughfare;

          destino.latitude = endereco.position.latitude;
          destino.longitude = endereco.position.longitude;

          String enderecoConfirmacao;
          enderecoConfirmacao = "\n Cidade: " + destino.cidade;
          enderecoConfirmacao += "\n Rua: " + destino.rua + ", " + destino.numero;
          enderecoConfirmacao += "\n Bairro: " + destino.bairro;
          enderecoConfirmacao += "\n Cep: " + destino.cep;

          showDialog(
              context: context,
              builder: (context){
                 return AlertDialog(
                   title: Text("Confirmação do endereço", style: TextStyle(fontSize: 17)),
                   content: Text(enderecoConfirmacao),
                   contentPadding: EdgeInsets.all(16),
                   actions: [
                     FlatButton(
                         onPressed: () => Navigator.pop(context),
                         child: Text("Cancelar", style: TextStyle(color: Colors.red))
                     ),
                     FlatButton(
                         onPressed: (){

                           //salvar requisição
                           _salvarRequisicao(destino);

                           Navigator.pop(context);
                         },
                         child: Text("Confirmar", style: TextStyle(color: Colors.green))
                     )
                   ],
                 );
              }
          );
       }

    }else{
       SnackBar(
         content: Text("Preencha o endereço"),
       );
    }
  }

  _salvarRequisicao(Destino destino) async {

    Usuario passageiro = await UsuarioFirebase.getDadosUsuarioLogado();

    Requisicao requisicao = Requisicao();
    requisicao.destino = destino;
    requisicao.passageiro = passageiro;
    requisicao.status = StatusRequisicao.AGUARDANDO;

    FirebaseFirestore db = FirebaseFirestore.instance;
    
    db.collection("requisicoes")
     .add(requisicao.toMap());

  }

  @override
  void initState() {
    super.initState();
    _recuperarUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel passageiro"),
        actions: [
          PopupMenuButton<String>(
              onSelected: _escolhaMenuItem,
              itemBuilder: (context){

                return itensMenu.map((String item) {
                   return PopupMenuItem<String>(
                     value: item,
                     child: Text(item),
                   );
                }).toList();

              },
          )
        ],
      ),
      body: Container(
        child: Stack(
           children: [
             GoogleMap(
               mapType: MapType.normal,
               initialCameraPosition: _posicaoCamera,
               onMapCreated: _onMapCreated,
               //myLocationEnabled: true,
               myLocationButtonEnabled: false,
               markers: _marcadores,
             ),
             Positioned(
                 top: 0,
                 left: 0,
                 right: 0,
                 child: Padding(
                   padding: EdgeInsets.all(10),
                   child: Container(
                     height: 50,
                     width: double.infinity,
                     decoration: BoxDecoration(
                       border: Border.all(color: Colors.grey),
                       borderRadius: BorderRadius.circular(3),
                       color: Colors.white
                     ),
                     child: TextField(
                       readOnly: true,
                       decoration: InputDecoration(
                         icon: Container(
                           margin: EdgeInsets.only(left: 20),
                           width: 10,
                           child: Icon(Icons.location_on, color: Colors.green),
                         ),
                         hintText: "Meu local",
                         border: InputBorder.none,
                         contentPadding: EdgeInsets.only(left: 15, top: 5)
                       ),
                     ),
                   ),
                 )
             ),
             Positioned(
                 top: 55,
                 left: 0,
                 right: 0,
                 child: Padding(
                   padding: EdgeInsets.all(10),
                   child: Container(
                     height: 50,
                     width: double.infinity,
                     decoration: BoxDecoration(
                         border: Border.all(color: Colors.grey),
                         borderRadius: BorderRadius.circular(3),
                         color: Colors.white
                     ),
                     child: TextField(
                       controller: _controllerDestino,
                       decoration: InputDecoration(
                           icon: Container(
                             margin: EdgeInsets.only(left: 20),
                             width: 10,
                             child: Icon(Icons.local_taxi, color: Colors.black),
                           ),
                           hintText: "Digite o destino",
                           border: InputBorder.none,
                           contentPadding: EdgeInsets.only(left: 15, top: 5)
                       ),
                     ),
                   ),
                 )
             ),
             Positioned(
                 left: 0,
                 right: 0,
                 bottom: 0,
                 child: Padding(
                   padding: Platform.isIOS ? EdgeInsets.fromLTRB(20, 10, 20, 25) :  EdgeInsets.all(10),
                   child: RaisedButton(
                     child: Text(
                       "Chamar Uber",
                       style: TextStyle(color: Colors.white, fontSize: 20),
                     ),
                     color: Color(0xff1ebbd8),
                     padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                     onPressed: (){
                        _chamarUber();
                     },
                   ),
                 )
             )
           ],
        ),
      ),
    );
  }
}
