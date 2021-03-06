import 'package:flutter/material.dart';
import 'package:uber/telas/Cadastro.dart';
import 'package:uber/telas/Corrida.dart';
import 'package:uber/telas/Home.dart';
import 'package:uber/telas/PainelMotorista.dart';
import 'package:uber/telas/PainelPassageiro.dart';

class Rotas {

  static const String ROTA_HOME = "/";
  static const String ROTA_CADASTRO = "/cadastro";
  static const String ROTA_PAINEL_MOTOR = "/painel-motorista";
  static const String ROTA_PAINEL_PASSAG = "/painel-passageiro";
  static const String ROTA_CORRIDA = "/corrida";

  static Route<dynamic> gerarRotas(RouteSettings settings){

    final args = settings.arguments;

    switch(settings.name){
      case ROTA_HOME:
        return MaterialPageRoute(
            builder: (_) => Home()
        );
      break;
      case ROTA_CADASTRO:
        return MaterialPageRoute(
            builder: (_) => Cadastro()
        );
      break;
      case ROTA_PAINEL_MOTOR:
        return MaterialPageRoute(
            builder: (_) => PainelMotorista()
        );
      break;
      case ROTA_PAINEL_PASSAG:
        return MaterialPageRoute(
            builder: (_) => PainelPassageiro()
        );
      break;
      case ROTA_CORRIDA:
        return MaterialPageRoute(
            builder: (_) => Corrida(args)
        );
      break;
      default:
        _erroRota();
    }
  }

  static Route<dynamic> _erroRota(){

    return MaterialPageRoute(
        builder: (_) {
          return Scaffold(
            appBar: AppBar(
              title: Text("Tela não encontrada!"),
            ),
            body: Center(
              child: Text("Tela não encontrada!"),
            ),
          );
        }
    );

  }

}