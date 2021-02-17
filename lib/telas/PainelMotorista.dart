import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:uber/Rotas.dart';
import 'package:uber/model/util/StatusRequisicao.dart';
import 'package:uber/model/util/UsuarioFirebase.dart';

class PainelMotorista extends StatefulWidget {
  @override
  _PainelMotoristaState createState() => _PainelMotoristaState();
}

class _PainelMotoristaState extends State<PainelMotorista> {

  List<String> itensMenu = [
    "Configurações", "Deslogar"
  ];
  final _controller = StreamController<QuerySnapshot>.broadcast();
  FirebaseFirestore db = FirebaseFirestore.instance;

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

  Stream<QuerySnapshot> _adicionarListenerRequisicoes(){

      final stream = db.collection("requisicoes").where("status", isEqualTo: StatusRequisicao.AGUARDANDO)
          .snapshots();

      stream.listen((dados) {
        _controller.add(dados);
      });
  }

  _recuperarRequisicaoAtivaMotorista() async {

    //Recuperar os dados do usuário logado
    User firebaseUser = await UsuarioFirebase.getUsuarioAtual();

    //Recuperar requisição ativa
    DocumentSnapshot documentSnapshot = await db.collection("requisicao_ativa_motorista")
      .doc(firebaseUser.uid).get();

    var dadosRequisicao = documentSnapshot.data();

    if(dadosRequisicao == null){
        _adicionarListenerRequisicoes();
    }else{
        String idRequisicao = dadosRequisicao["id_requisicao"];
        Navigator.pushReplacementNamed(context, Rotas.ROTA_CORRIDA, arguments: idRequisicao);
    }
  }

  @override
  void initState() {
    super.initState();
   /*
      Recuperar requisição ativa para verificar se motorista está
      atendendo alguma requisição e envia ele para tela de corrida
   */
   _recuperarRequisicaoAtivaMotorista();

  }

  @override
  Widget build(BuildContext context) {

    var mensagemCarregando = Center(
      child: Column(
        children: [
          Text("Carregando requisições"),
          CircularProgressIndicator()
        ],
      ),
    );

    var mensagemNaoTemDados = Center(
      child: Text(
        "Você não tem nenhuma requisição :( ",
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold
        ),
      )
    );

    return Scaffold(
      appBar: AppBar(
        title: Text("Painel motorista"),
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
      body: StreamBuilder<QuerySnapshot>(
        stream: _controller.stream,
        builder: (context, snapshot){
            switch(snapshot.connectionState){
              case ConnectionState.none:
              case ConnectionState.waiting:
                  return mensagemCarregando;
              break;
              case ConnectionState.active:
              case ConnectionState.done:

                if(snapshot.hasError){
                  return Text("Erro ao carregar os dados!");
                }else{

                    QuerySnapshot querySnapshot = snapshot.data;
                    if(querySnapshot.docs.length == 0){
                        return mensagemNaoTemDados;
                    }else{
                        return ListView.separated(
                            itemCount: querySnapshot.docs.length,
                            separatorBuilder: (context, index) => Divider(
                              height: 2,
                              color: Colors.grey,
                            ),
                            itemBuilder: (context, index){

                               List<DocumentSnapshot> requisicoes = querySnapshot.docs.toList();
                               DocumentSnapshot item = requisicoes[index];

                               String idRequisicao = item["id"];
                               String nomePassageiro = item["passageiro"]["nome"];
                               String rua = item["destino"]["rua"];
                               String numero = item["destino"]["numero"];

                               return ListTile(
                                 title: Text(nomePassageiro),
                                 subtitle: Text("destino: $rua, $numero"),
                                 onTap: (){
                                    Navigator.pushNamed(
                                        context,
                                        Rotas.ROTA_CORRIDA,
                                        arguments: idRequisicao
                                    );
                                 },
                               );

                            }
                        );
                    }
                }

              break;
            }
        },
      ),
    );
  }
}
