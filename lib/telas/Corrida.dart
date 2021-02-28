import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uber/Rotas.dart';
import 'package:uber/model/Marcador.dart';
import 'package:uber/model/Usuario.dart';
import 'package:uber/model/util/StatusRequisicao.dart';
import 'package:uber/model/util/UsuarioFirebase.dart';

class Corrida extends StatefulWidget {

  String idRequisicao;

  Corrida( this.idRequisicao );

  @override
  _CorridaState createState() => _CorridaState();
}

class _CorridaState extends State<Corrida> {

  Completer<GoogleMapController> _controller = Completer();
  CameraPosition _posicaoCamera =
  CameraPosition(target: LatLng(-23.563999, -46.653256));
  Set<Marker> _marcadores = {};
  Map<String, dynamic> _dadosRequisicao;
  String _idRequisicao;
  Position _localMotorista;
  String _statusRequisicao = StatusRequisicao.AGUARDANDO;
  List<String> itensMenu = ["Configurações", "Deslogar"];

  //Controles para exibição na tela
  String _textoBotao = "Aceitar corrida";
  Color _corBotao = Color(0xff1ebbd8);
  Function _funcaoBotao;
  String _mensagemStatus = "";

  _alterarBotaoPrincipal(String texto, Color cor, Function funcao) {
    setState(() {
      _textoBotao = texto;
      _corBotao = cor;
      _funcaoBotao = funcao;
    });
  }

  _onMapCreated(GoogleMapController controller) {
    _controller.complete(controller);
  }

  _adicionarListenerLocalizacao() {
    var geolocator = Geolocator();
    var locationOptions =
    LocationOptions(accuracy: LocationAccuracy.high, distanceFilter: 10);

    geolocator.getPositionStream(locationOptions).listen((Position position) {

      if( position != null ){

        if( _idRequisicao != null && _idRequisicao.isNotEmpty ){

          if( _statusRequisicao != StatusRequisicao.AGUARDANDO ){

            //Atualiza local do passageiro
            UsuarioFirebase.atualizarDadosLocalizacao(
                _idRequisicao,
                position.latitude,
                position.longitude
            );

          }else{//aguardando
            setState(() {
              _localMotorista = position;
            });
            _statusAguardando();
          }
        }
      }
    });
  }

  _recuperaUltimaLocalizacaoConhecida() async {
    Position position = await Geolocator()
        .getLastKnownPosition(desiredAccuracy: LocationAccuracy.high);

    if (position != null) {
      //Atualizar localização em tempo real do motorista

    }
  }

  _movimentarCamera(CameraPosition cameraPosition) async {
    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(CameraUpdate.newCameraPosition(cameraPosition));
  }

  _exibirMarcador(Position local, String icone, String infoWindow) async {

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        icone)
        .then((BitmapDescriptor bitmapDescriptor) {
      Marker marcador = Marker(
          markerId: MarkerId(icone),
          position: LatLng(local.latitude, local.longitude),
          infoWindow: InfoWindow(title: infoWindow),
          icon: bitmapDescriptor);

      setState(() {
        _marcadores.add(marcador);
      });
    });
  }

  _recuperarRequisicao() async {

    String idRequisicao = widget.idRequisicao;

    FirebaseFirestore db = FirebaseFirestore.instance;
    DocumentSnapshot documentSnapshot = await db
        .collection("requisicoes")
        .doc( idRequisicao )
        .get();

  }

  _adicionarListenerRequisicao() async {

    FirebaseFirestore db = FirebaseFirestore.instance;

    await db.collection("requisicoes")
        .doc( _idRequisicao ).snapshots().listen((snapshot){

      if( snapshot.data != null ){

        _dadosRequisicao = snapshot.data();

        Map<String, dynamic> dados = snapshot.data();
        _statusRequisicao = dados["status"];

        switch( _statusRequisicao ){
          case StatusRequisicao.AGUARDANDO :
            _statusAguardando();
          break;
          case StatusRequisicao.A_CAMINHO :
            _statusACaminho();
          break;
          case StatusRequisicao.VIAGEM :
            _statusEmViagem();
          break;
          case StatusRequisicao.FINALIZADA :
            _statusFinalizada();
          break;
          case StatusRequisicao.CONFIRMADA :
            _statusConfirmada();
          break;
        }
      }
    });
  }

  _statusAguardando() {

    _alterarBotaoPrincipal(
        "Aceitar corrida",
        Color(0xff1ebbd8),
            () {
          _aceitarCorrida();
        });

    if( _localMotorista != null ){

      double motoristaLat = _localMotorista.latitude;
      double motoristaLon = _localMotorista.longitude;

      Position position = Position(
          latitude: motoristaLat, longitude: motoristaLon
      );
      _exibirMarcador(
          position,
          "imagens/motorista.png",
          "Motorista"
      );

      CameraPosition cameraPosition = CameraPosition(
          target: LatLng(position.latitude, position.longitude), zoom: 19);

      _movimentarCamera( cameraPosition );

    }
  }

  _statusACaminho() {

    _mensagemStatus = "A caminho do passageiro";
    _alterarBotaoPrincipal(
        "Iniciar corrida",
        Color(0xff1ebbd8),
            (){
          _iniciarCorrida();
        }
    );

    double latitudeDestino = _dadosRequisicao["passageiro"]["latitude"];
    double longitudeDestino = _dadosRequisicao["passageiro"]["longitude"];

    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];


    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeOrigem, longitudeOrigem),
        "imagens/motorista.png",
        "Local motorista"
    );

    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino, longitudeDestino),
        "imagens/passageiro.png",
        "Local destino"
    );

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);
  }

  _finalizarCorrida(){

    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes")
    .doc(_idRequisicao)
    .update({
      "status": StatusRequisicao.FINALIZADA
    });

    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db.collection("requisicao_ativa")
            .doc(idPassageiro)
            .update({"status": StatusRequisicao.FINALIZADA});

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db.collection("requisicao_ativa_motorista")
         .doc(idMotorista)
         .update({"status": StatusRequisicao.FINALIZADA});

  }

  _statusFinalizada() async {

    //Calcula valor da corrida
    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];

    double latitudeOrigem = _dadosRequisicao["origem"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["origem"]["longitude"];

    double distanciaEmMetros = await Geolocator().distanceBetween(
        latitudeOrigem,
        longitudeOrigem,
        latitudeDestino,
        longitudeDestino
    );

    //Converte para KM
    double distanciaKm = distanciaEmMetros / 1000;

    // 8 é o valor cobrado por KM
    double valorViagem = distanciaKm * 8;

    //Formatar valor viagem
    var f = new NumberFormat("#,##0.00", "pt_BR");
    var valorViagemFormatado = f.format(valorViagem);

    _mensagemStatus = "Viagem finalizada";
    _alterarBotaoPrincipal(
        "Confirmar - R\$ ${valorViagemFormatado}",
        Color(0xff1ebbd8),
            (){
          _confirmarCorrida();
        }
    );

    _marcadores = {};
    Position position = Position(
        latitude: latitudeDestino, longitude: longitudeDestino
    );
    _exibirMarcador(
        position,
        "imagens/destino.png",
        "Destino"
    );

    CameraPosition cameraPosition = CameraPosition(
        target: LatLng(position.latitude, position.longitude), zoom: 19);

    _movimentarCamera( cameraPosition );

  }

  _statusConfirmada(){

      Navigator.pushReplacementNamed(context, Rotas.ROTA_PAINEL_MOTOR);

  }

  _confirmarCorrida(){

    FirebaseFirestore db = FirebaseFirestore.instance;
    db.collection("requisicoes")
        .doc(_idRequisicao)
        .update({
      "status": StatusRequisicao.CONFIRMADA
    });

    String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
    db.collection("requisicao_ativa")
        .doc(idPassageiro)
        .delete();

    String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
    db.collection("requisicao_ativa_motorista")
        .doc(idMotorista)
        .delete();

  }

  _statusEmViagem() {

    _mensagemStatus = "Em viagem";
    _alterarBotaoPrincipal(
        "Finalizar corrida",
        Color(0xff1ebbd8),
            (){
          _finalizarCorrida();
        }
    );

    double latitudeDestino = _dadosRequisicao["destino"]["latitude"];
    double longitudeDestino = _dadosRequisicao["destino"]["longitude"];

    double latitudeOrigem = _dadosRequisicao["motorista"]["latitude"];
    double longitudeOrigem = _dadosRequisicao["motorista"]["longitude"];

    Marcador marcadorOrigem = Marcador(
        LatLng(latitudeOrigem, longitudeOrigem),
        "imagens/motorista.png",
        "Local motorista"
    );

    Marcador marcadorDestino = Marcador(
        LatLng(latitudeDestino, longitudeDestino),
        "imagens/destino.png",
        "Local destino"
    );

    _exibirCentralizarDoisMarcadores(marcadorOrigem, marcadorDestino);

  }

  _exibirCentralizarDoisMarcadores( Marcador marcadorOrigem, Marcador marcadorDestino ) {

      double latitudeOrigem = marcadorOrigem.local.latitude;
      double longitudeOrigem = marcadorOrigem.local.longitude;

      double latitudeDestino = marcadorDestino.local.latitude;
      double longitudeDestino = marcadorDestino.local.longitude;

      //Exibir dois marcadores
      _exibirDoisMarcadores(
          marcadorOrigem,
          marcadorDestino
      );

      //'southwest.latitude <= northeast.latitude': is not true
      var nLat, nLon, sLat, sLon;

      if( latitudeOrigem <= latitudeDestino ){
        sLat = latitudeOrigem;
        nLat = latitudeDestino;
      }else{
        sLat = latitudeDestino;
        nLat = latitudeOrigem;
      }

      if( longitudeOrigem <=  longitudeDestino ){
        sLon = longitudeOrigem;
        nLon = longitudeDestino;
      }else{
        sLon = longitudeDestino;
        nLon = longitudeOrigem;
      }
      //-23.560925, -46.650623
      _movimentarCameraBounds(
          LatLngBounds(
              northeast: LatLng(nLat, nLon), //nordeste
              southwest: LatLng(sLat, sLon) //sudoeste
          )
      );

  }

    _iniciarCorrida(){

      FirebaseFirestore db = FirebaseFirestore.instance;
      db.collection("requisicoes")
      .doc(_idRequisicao)
      .update({
        "origem": {
          "latitude": _dadosRequisicao["motorista"]["latitude"],
          "longitude": _dadosRequisicao["motorista"]["longitude"]
        },
        "status": StatusRequisicao.VIAGEM
      });

      String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
      db.collection("requisicao_ativa")
      .doc(idPassageiro)
      .update({"status": StatusRequisicao.VIAGEM});

      String idMotorista = _dadosRequisicao["motorista"]["idUsuario"];
      db.collection("requisicao_ativa_motorista")
          .doc(idMotorista)
          .update({"status": StatusRequisicao.VIAGEM});

  }

  _movimentarCameraBounds(LatLngBounds latLngBounds) async {

    GoogleMapController googleMapController = await _controller.future;
    googleMapController
        .animateCamera(
        CameraUpdate.newLatLngBounds(
            latLngBounds,
            100
        )
    );
  }

  _exibirDoisMarcadores(Marcador marcadorOrigem, Marcador marcadorDestino ){

    double pixelRatio = MediaQuery.of(context).devicePixelRatio;

    LatLng latLngOrigem = marcadorOrigem.local;
    LatLng latLngDestino = marcadorDestino.local;

    Set<Marker> _listaMarcadores = {};
    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        marcadorOrigem.caminhoImagem)
        .then((BitmapDescriptor icone) {
      Marker mOrigem  = Marker(
          markerId: MarkerId(marcadorOrigem.caminhoImagem),
          position: LatLng(latLngOrigem.latitude, latLngOrigem.longitude),
          infoWindow: InfoWindow(title: marcadorOrigem.titulo),
          icon: icone);
      _listaMarcadores.add( mOrigem  );
    });

    BitmapDescriptor.fromAssetImage(
        ImageConfiguration(devicePixelRatio: pixelRatio),
        marcadorDestino.caminhoImagem)
        .then((BitmapDescriptor icone) {
      Marker mDestino = Marker(
          markerId: MarkerId(marcadorDestino.caminhoImagem),
          position: LatLng(latLngDestino.latitude, latLngDestino.longitude),
          infoWindow: InfoWindow(title: marcadorDestino.titulo),
          icon: icone);
      _listaMarcadores.add( mDestino );
    });

    setState(() {
      _marcadores = _listaMarcadores;
    });

  }

  _aceitarCorrida() async {

    //Recuperar dados do motorista
    Usuario motorista   = await UsuarioFirebase.getDadosUsuarioLogado();
    motorista.latitude  = _localMotorista.latitude;
    motorista.longitude = _localMotorista.longitude;

    FirebaseFirestore db = FirebaseFirestore.instance;
    String idRequisicao = _dadosRequisicao["id"];

    db.collection("requisicoes")
        .doc( idRequisicao ).update({
      "motorista" : motorista.toMap(),
      "status" : StatusRequisicao.A_CAMINHO,
    }).then((_){

      //atualiza requisicao ativa
      String idPassageiro = _dadosRequisicao["passageiro"]["idUsuario"];
      db.collection("requisicao_ativa")
          .doc( idPassageiro ).update({
        "status" : StatusRequisicao.A_CAMINHO,
      });

      //Salvar requisicao ativa para motorista
      String idMotorista = motorista.idUsuario;
      db.collection("requisicao_ativa_motorista")
          .doc( idMotorista )
          .set({
        "id_requisicao" : idRequisicao,
        "id_usuario" : idMotorista,
        "status" : StatusRequisicao.A_CAMINHO,
      });

    });

  }

  _deslogarUsuario() async {
    FirebaseAuth auth = FirebaseAuth.instance;

    await auth.signOut();
    Navigator.pushReplacementNamed(context, "/");
  }

  @override
  void initState() {
    super.initState();

    //_deslogarUsuario();

    _idRequisicao = widget.idRequisicao;

    // adicionar listener para mudanças na requisicao
    _adicionarListenerRequisicao();

    //_recuperaUltimaLocalizacaoConhecida();
    _adicionarListenerLocalizacao();

  }

  _escolhaMenuItem(String escolha) {
    switch (escolha) {
      case "Deslogar":
        _deslogarUsuario();
        break;
      case "Configurações":
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Painel corrida - " + _mensagemStatus,
          style: TextStyle(fontSize: 15),
        ),
        actions: <Widget>[
          PopupMenuButton<String>(
            onSelected: _escolhaMenuItem,
            itemBuilder: (context) {
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
          children: <Widget>[
            GoogleMap(
              mapType: MapType.normal,
              initialCameraPosition: _posicaoCamera,
              onMapCreated: _onMapCreated,
              //myLocationEnabled: true,
              myLocationButtonEnabled: false,
              markers: _marcadores,
              //-23,559200, -46,658878
            ),
            Positioned(
              right: 0,
              left: 0,
              bottom: 0,
              child: Padding(
                padding: Platform.isIOS
                    ? EdgeInsets.fromLTRB(20, 10, 20, 25)
                    : EdgeInsets.all(10),
                child: RaisedButton(
                    child: Text(
                      _textoBotao,
                      style: TextStyle(color: Colors.white, fontSize: 20),
                    ),
                    color: _corBotao,
                    padding: EdgeInsets.fromLTRB(32, 16, 32, 16),
                    onPressed: _funcaoBotao),
              ),
            )
          ],
        ),
      ),
    );
  }
}
